"""Import text draw results and queue draw-list follow-up tasks."""

import asyncio
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from typing import Final

from ..database import DB, Database
from ..logging import get_logger
from ..utilities.scrapper import (
    PrizeBondDrawResult,
    PrizeBondResults,
    PrizeBondScraper,
    PrizeBondTextResult,
    create_prize_bond_client,
)
from ..utilities.scrapper.source2_client import PrizeBondPKClient
from ..utilities.scrapper.models import ScheduledDraw, UpcomingDrawScraper
from .drawlist_import import (
    import_text_draw_result,
    remove_completed_drawlist_tasks,
    remove_drawlist_task_for_result,
)

logger = get_logger()

PAKISTAN_STANDARD_TIME: Final = timezone(timedelta(hours=5), "PKT")


async def ensure_admin_tasks_table(database: Database = DB) -> None:
    """Create the task table and indexes if this database has not been initialized."""
    table_exists = await database.fetchval(
        """
        SELECT EXISTS (
            SELECT 1
            FROM information_schema.tables
            WHERE table_schema = 'public' AND table_name = 'admin_tasks'
        )
        """
    )
    if table_exists:
        return

    schema_file = (
        Path(__file__).resolve().parent.parent
        / "database"
        / "schema"
        / "13-Admin-Tasks.sql"
    )
    await database.execute(schema_file.read_text(encoding="utf-8"))


async def process_drawlists(
    database: Database = DB,
    client: PrizeBondScraper | None = None,
    upcoming_draw_client: UpcomingDrawScraper | None = None,
) -> None:
    """Import available text results and enqueue manual or missing-result tasks."""
    scraper = client or create_prize_bond_client()
    drawlists = await scraper.fetch_draw_result_links()
    text_results = await scraper.fetch_text_draw_results(drawlists)

    for drawlist in drawlists:
        results_by_date: dict[date, list[PrizeBondDrawResult]] = {}
        for result in drawlist.results:
            results_by_date.setdefault(result.draw_date, []).append(result)
        for draw_date, source_results in results_by_date.items():
            if any(_can_auto_import(result) for result in source_results):
                continue
            for result in source_results:
                await _create_task(
                    database,
                    task_type="manual_pdf_review",
                    title="Manually review non-text draw result",
                    description=(
                        f"The {result.file_type.upper()} draw result cannot be "
                        "automatically imported and must be reviewed and entered "
                        "by an administrator."
                    ),
                    result=result,
                    denomination=drawlist.denomination,
                )

    for result in text_results:
        if result.error is not None:
            logger.warning(
                "Could not import draw result (denomination=%s, date=%s, url=%s): %s",
                result.denomination,
                result.draw_date,
                result.url,
                result.error,
            )
            continue
        try:
            imported_count = await import_text_draw_result(result, database)
            if imported_count is None:
                logger.info(
                    "Skipped existing draw result (denomination=%s, date=%s).",
                    result.denomination,
                    result.draw_date,
                )
            else:
                removed_task_count = await remove_drawlist_task_for_result(
                    result.draw_date,
                    result.denomination,
                    database,
                )
                if removed_task_count:
                    logger.info(
                        "Removed draw-list task after importing result "
                        "(denomination=%s, date=%s).",
                        result.denomination,
                        result.draw_date,
                    )
        except Exception:
            logger.exception(
                "Could not save parsed draw result (denomination=%s, date=%s, url=%s).",
                result.denomination,
                result.draw_date,
                result.url,
            )

    results_by_denomination_date: dict[
        tuple[date, int], list[PrizeBondDrawResult]
    ] = {}
    for drawlist in drawlists:
        for result in drawlist.results:
            key = (result.draw_date, drawlist.denomination)
            results_by_denomination_date.setdefault(key, []).append(result)

    for (draw_date, denomination), source_results in (
        results_by_denomination_date.items()
    ):
        has_winners = await database.fetchval(
            """
            SELECT EXISTS (
                SELECT 1
                FROM "drawlists" AS d
                JOIN "draw_winners" AS w ON w."draw_id" = d."draw_id"
                WHERE d."draw_date" = $1 AND d."denomination" = $2
            )
            """,
            draw_date,
            denomination,
        )
        if not has_winners:
            if not any(_can_auto_import(item) for item in source_results):
                continue
            source = next(
                (item for item in source_results if _can_auto_import(item)),
                source_results[0],
            )
            await _create_task(
                database,
                task_type="missing_draw_result",
                title="Add missing draw result",
                description=(
                    "A draw result listed by National Savings is not present "
                    "in the database."
                ),
                result=source,
                denomination=denomination,
            )

    removed_tasks = await remove_completed_drawlist_tasks(database)
    if removed_tasks:
        logger.info("Removed %s completed draw-list admin tasks.", removed_tasks)

    schedule_scraper = upcoming_draw_client
    if schedule_scraper is None:
        schedule_scraper = (
            scraper
            if isinstance(scraper, PrizeBondPKClient)
            else PrizeBondPKClient()
        )
    upcoming_draws = await schedule_scraper.fetch_upcoming_draws()
    await _upsert_upcoming_draws(upcoming_draws, database)

    logger.info(
        "Processed draw-list results and schedule "
        "(text_files=%s, source_draws=%s, upcoming_draws=%s).",
        len(text_results),
        len(results_by_denomination_date),
        len(upcoming_draws),
    )


def _can_auto_import(result: PrizeBondDrawResult) -> bool:
    """Whether the selected source can parse this result automatically."""
    return result.file_type == "txt" or result.can_auto_import


async def _upsert_upcoming_draws(
    upcoming_draws: list[ScheduledDraw],
    database: Database,
) -> None:
    """Synchronize PrizeBondPK scheduled draws into the upcoming-draw table."""
    for draw in upcoming_draws:
        await database.execute(
            """
            INSERT INTO "upcoming_draws" ("draw_date", "denomination", "location")
            VALUES ($1, $2, $3)
            ON CONFLICT ("draw_date", "denomination")
            DO UPDATE SET "location" = EXCLUDED."location"
            """,
            date.fromisoformat(draw["date"]),
            draw["denomination"],
            draw["city"] or None,
        )


async def run_drawlist_automation() -> None:
    """Run immediately, then repeat every day at 10 PM Pakistan Standard Time."""
    next_run = _next_scheduled_run(datetime.now(PAKISTAN_STANDARD_TIME))
    await _run_drawlist_cycle()

    while True:
        delay = max(
            0.0,
            (next_run - datetime.now(PAKISTAN_STANDARD_TIME)).total_seconds(),
        )
        await asyncio.sleep(delay)
        await _run_drawlist_cycle()
        next_run += timedelta(days=1)


def _next_scheduled_run(now: datetime) -> datetime:
    """Return the next 10 PM boundary in Pakistan Standard Time."""
    next_run = now.replace(hour=22, minute=0, second=0, microsecond=0)
    if next_run <= now:
        next_run += timedelta(days=1)
    return next_run


async def _run_drawlist_cycle() -> None:
    try:
        await process_drawlists()
    except Exception:
        logger.exception("Automated draw-list processing failed.")


async def _create_task(
    database: Database,
    *,
    task_type: str,
    title: str,
    description: str,
    result: PrizeBondDrawResult | PrizeBondTextResult,
    denomination: int,
) -> None:
    """Add an idempotent administrator task for a draw result."""
    await database.execute(
        """
        INSERT INTO "admin_tasks" (
            "task_type", "title", "description", "draw_date",
            "denomination", "source_url"
        )
        VALUES ($1, $2, $3, $4, $5, $6)
        ON CONFLICT DO NOTHING
        """,
        task_type,
        title,
        description,
        result.draw_date,
        denomination,
        result.url,
    )
