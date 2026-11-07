"""Parse and store prize-bond draw results."""

from datetime import date
from typing import Final

from ..database import DB, Database
from ..logging import get_logger
from ..utilities.scrapper.models import PrizeBondTextResult
from ..utilities.scrapper.parsers import (
    _decode_text_file,
    _parse_prize_numbers,
)

logger = get_logger()

PRIZE_AMOUNTS: Final[dict[int, tuple[int, int, int]]] = {
    100: (700_000, 200_000, 1_000),
    200: (750_000, 250_000, 1_250),
    750: (1_500_000, 500_000, 9_300),
    1500: (3_000_000, 1_000_000, 18_500),
    25000: (30_000_000, 10_000_000, 300_000),
    40000: (75_000_000, 25_000_000, 500_000),
}
EXPECTED_PRIZE_NUMBER_COUNTS: Final[dict[int, tuple[int, int]]] = {
    100: (1, 3),
    200: (1, 5),
    750: (1, 3),
    1500: (1, 3),
    25000: (2, 5),
    40000: (1, 3),
}


def parse_text_draw_result(
    content: bytes,
    denomination: int,
    draw_date: date,
    source: str,
) -> PrizeBondTextResult:
    """Parse and validate a text draw list before it is written to the database."""
    try:
        prize_numbers = _parse_prize_numbers(
            _decode_text_file(content),
            denomination,
        )
    except ValueError as error:
        raise ValueError(f"Could not parse the draw-list text file: {error}") from error

    expected_counts = EXPECTED_PRIZE_NUMBER_COUNTS.get(denomination)
    if expected_counts is None:
        raise ValueError(f"Unsupported prize bond denomination: {denomination}")
    for prize_name, numbers, expected_count in zip(
        ("first", "second"),
        prize_numbers[:2],
        expected_counts,
        strict=True,
    ):
        if len(numbers) != expected_count:
            raise ValueError(
                f"Expected {expected_count} {prize_name}-prize bond number(s), "
                f"but found {len(numbers)}."
            )

    normalized_prizes = tuple(
        tuple(_normalize_bond_number(number) for number in numbers)
        for numbers in prize_numbers
    )
    missing_prizes = [
        prize_name
        for prize_name, numbers in zip(
            ("first", "second", "third"),
            normalized_prizes,
            strict=True,
        )
        if not numbers
    ]
    if missing_prizes:
        raise ValueError(
            f"The text file is missing winning numbers for the "
            f"{', '.join(missing_prizes)} prize."
        )

    all_numbers = [number for prize in normalized_prizes for number in prize]
    if len(all_numbers) != len(set(all_numbers)):
        raise ValueError("A bond number cannot appear more than once in a draw list.")

    return PrizeBondTextResult(
        denomination=denomination,
        draw_date=draw_date,
        url=source,
        first_prize_numbers=normalized_prizes[0],
        second_prize_numbers=normalized_prizes[1],
        third_prize_numbers=normalized_prizes[2],
    )


def _normalize_bond_number(number: str) -> str:
    """Return a parsed bond number in the database's six-digit format."""
    if not number.isdigit() or not 1 <= int(number) <= 999999:
        raise ValueError(f"Invalid prize bond number: {number}")
    return number.zfill(6)


async def import_text_draw_result(
    result: PrizeBondTextResult,
    database: Database = DB,
) -> int | None:
    """Insert a draw once and return its winner count, or None if it exists."""
    try:
        prize_amounts = PRIZE_AMOUNTS[result.denomination]
    except KeyError as error:
        raise ValueError(
            f"Unsupported prize bond denomination: {result.denomination}"
        ) from error

    normalized_prizes = [
        tuple(_normalize_bond_number(number) for number in numbers)
        for numbers in (
            result.first_prize_numbers,
            result.second_prize_numbers,
            result.third_prize_numbers,
        )
    ]
    winners = [
        (number, position, prize_amounts[position - 1])
        for position, numbers in enumerate(normalized_prizes, start=1)
        for number in numbers
    ]
    if not winners:
        raise ValueError("The draw list does not contain any winning bond numbers.")
    if len({number for number, _, _ in winners}) != len(winners):
        raise ValueError("A bond number cannot appear more than once in a draw list.")

    async with database.transaction() as connection:
        draw_id = await connection.fetchval(
            """
            INSERT INTO "drawlists" ("draw_date", "denomination")
            VALUES ($1, $2)
            ON CONFLICT ("draw_date", "denomination")
            DO NOTHING
            RETURNING "draw_id"
            """,
            result.draw_date,
            result.denomination,
        )
        if draw_id is None:
            logger.info(
                "Skipped existing draw result (denomination=%s, date=%s).",
                result.denomination,
                result.draw_date,
            )
            return None

        await connection.executemany(
            """
            INSERT INTO "draw_winners" (
                "draw_id", "bond_number", "prize_position", "prize_amount"
            )
            VALUES ($1, $2, $3, $4)
            """,
            [
                (draw_id, number, position, amount)
                for number, position, amount in winners
            ],
        )

    logger.info(
        "Imported draw result (denomination=%s, date=%s, winners=%s).",
        result.denomination,
        result.draw_date,
        len(winners),
    )
    return len(winners)


async def remove_drawlist_task_for_result(
    draw_date: date,
    denomination: int,
    database: Database = DB,
) -> int:
    """Remove follow-up tasks after a source successfully imports that draw."""
    result = await database.execute(
        """
        DELETE FROM "admin_tasks"
        WHERE "task_type" IN ('missing_draw_result', 'manual_pdf_review')
          AND "draw_date" = $1
          AND "denomination" = $2
        """,
        draw_date,
        denomination,
    )
    return int(result.split()[-1])


async def remove_completed_drawlist_tasks(database: Database = DB) -> int:
    """Remove admin tasks for draws that now have at least one stored winner."""
    result = await database.execute(
        """
        DELETE FROM "admin_tasks" AS task
        WHERE task."task_type" IN ('missing_draw_result', 'manual_pdf_review')
          AND EXISTS (
              SELECT 1
              FROM "drawlists" AS draw
              JOIN "draw_winners" AS winner
                ON winner."draw_id" = draw."draw_id"
              WHERE draw."draw_date" = task."draw_date"
                AND draw."denomination" = task."denomination"
              GROUP BY draw."draw_id"
              HAVING COUNT(DISTINCT winner."prize_position") = 3
          )
        """
    )
    return int(result.split()[-1])
