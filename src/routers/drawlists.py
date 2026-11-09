"""
* Project Name: BONDVAULT PK

* Description: 

* Author: Wolf4605
* Email: mab4605@gmail.com

* Date: 2026-11-02 10:40:01

* Last Modified by: Wolf4605
* Last Modified time: 2026-11-02 10:40:04

* License: MIT
* Copyright© BondVault PK. All rights reserved.
"""
from datetime import date, datetime
from io import BytesIO
from pathlib import Path
from typing import Annotated
from uuid import UUID

from asyncpg import Record
from fastapi import APIRouter, Depends, File, Form, UploadFile, status
from fastapi.responses import Response
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)
from starlette.exceptions import HTTPException

from .. import models, payloads, responses
from ..configs import PRIZE_POSITION_NAMES, PrizeBondDenominations
from ..database import DB
from ..services.drawlist_automation import PAKISTAN_STANDARD_TIME
from ..services.drawlist_import import (
    import_text_draw_result,
    parse_text_draw_result,
    remove_completed_drawlist_tasks,
)
from ..utilities.auth_dependencies import get_current_admin, get_current_user

router = APIRouter(
    prefix = "/drawlists",
    tags = ["Drawlists"]
)
user_router = APIRouter(
    prefix="/user/drawlists",
    tags=["User Drawlists"],
)


async def _fetch_user_drawlist(draw_id: UUID) -> list[Record]:
    """Fetch one draw and its winners, returning 404 when it does not exist."""
    records = await DB.fetch(
        """
        SELECT d."draw_id", d."draw_date", d."denomination",
               w."bond_number", w."prize_position", w."prize_amount"
        FROM "drawlists" AS d
        LEFT JOIN "draw_winners" AS w ON w."draw_id" = d."draw_id"
        WHERE d."draw_id" = $1
        ORDER BY w."prize_position" ASC, w."bond_number" ASC
        """,
        draw_id,
    )
    if not records:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Draw list not found.",
        )
    return records


def _drawlist_winners_response(
    records: list[Record],
) -> responses.DrawListWinnersResponse:
    """Build the public draw/winner response from joined database records."""
    draw = records[0]
    winners = [
        responses.DrawListWinner(
            bond_number=record["bond_number"],
            prize_position=record["prize_position"],
            prize_name=PRIZE_POSITION_NAMES[record["prize_position"]],
            prize_amount=record["prize_amount"],
        )
        for record in records
        if record["bond_number"] is not None
    ]
    return responses.DrawListWinnersResponse(
        draw_id=draw["draw_id"],
        draw_date=draw["draw_date"],
        denomination=draw["denomination"],
        winners=winners,
        total=len(winners),
    )


@user_router.get(
    path="",
    response_model=list[responses.DrawListSummary],
    summary="Fetch all available draw lists",
)
async def get_user_drawlists(
    user: Annotated[models.UserInfo, Depends(get_current_user)],
) -> list[responses.DrawListSummary]:
    """Return all imported draw lists and the count of winning bonds in each."""
    records = await DB.fetch(
        """
        SELECT d."draw_id", d."draw_date", d."denomination",
               COUNT(w."bond_number")::INT AS "winner_count"
        FROM "drawlists" AS d
        LEFT JOIN "draw_winners" AS w ON w."draw_id" = d."draw_id"
        GROUP BY d."draw_id", d."draw_date", d."denomination"
        ORDER BY d."draw_date" DESC, d."denomination" ASC
        """
    )
    return [
        responses.DrawListSummary.model_validate(dict(record))
        for record in records
    ]


@user_router.get(
    path="/{draw_id}/bonds",
    response_model=responses.DrawListWinnersResponse,
    summary="Fetch the winning bonds in a draw list",
)
async def get_user_drawlist_bonds(
    draw_id: UUID,
    user: Annotated[models.UserInfo, Depends(get_current_user)],
) -> responses.DrawListWinnersResponse:
    """Return all winning bonds and prize details for one imported draw."""
    records = await _fetch_user_drawlist(draw_id)
    return _drawlist_winners_response(records)


@user_router.get(
    path="/{draw_id}/pdf",
    response_class=Response,
    responses={
        status.HTTP_200_OK: {
            "content": {"application/pdf": {}},
            "description": "PDF containing the draw list and its winning bonds.",
        },
        status.HTTP_404_NOT_FOUND: {
            "description": "The requested draw list does not exist.",
        },
    },
    summary="Download a draw list as a PDF",
)
async def download_user_drawlist_pdf(
    draw_id: UUID,
    user: Annotated[models.UserInfo, Depends(get_current_user)],
) -> Response:
    """Generate an in-memory PDF for one draw list."""
    drawlist = _drawlist_winners_response(await _fetch_user_drawlist(draw_id))
    buffer = BytesIO()
    document = SimpleDocTemplate(
        buffer,
        pagesize=A4,
        rightMargin=18 * mm,
        leftMargin=18 * mm,
        topMargin=18 * mm,
        bottomMargin=18 * mm,
        title=(
            f"Prize Bond Draw List - {drawlist.denomination} - "
            f"{drawlist.draw_date.isoformat()}"
        ),
        author="BondVault PK",
    )
    styles = getSampleStyleSheet()
    title_style = ParagraphStyle(
        "DrawListTitle",
        parent=styles["Title"],
        alignment=TA_CENTER,
        textColor=colors.HexColor("#183B66"),
    )
    story = [
        Paragraph("Prize Bond Draw List", title_style),
        Spacer(1, 5 * mm),
        Paragraph(
            f"Denomination: Rs. {int(drawlist.denomination):,} "
            f"&nbsp;&nbsp; Draw date: {drawlist.draw_date.isoformat()}",
            styles["BodyText"],
        ),
        Paragraph(f"Winning bonds: {drawlist.total}", styles["BodyText"]),
        Spacer(1, 5 * mm),
    ]
    rows = [["No.", "Bond number", "Prize position", "Prize amount"]]
    rows.extend(
        [
            str(index),
            winner.bond_number,
            winner.prize_name,
            f"Rs. {winner.prize_amount:,}",
        ]
        for index, winner in enumerate(drawlist.winners, start=1)
    )
    table = Table(
        rows,
        repeatRows=1,
        colWidths=(16 * mm, 38 * mm, 55 * mm, 45 * mm),
    )
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#183B66")),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                ("GRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#B8C5D3")),
                (
                    "ROWBACKGROUNDS",
                    (0, 1),
                    (-1, -1),
                    [colors.white, colors.HexColor("#F1F5F9")],
                ),
                ("ALIGN", (0, 0), (0, -1), "CENTER"),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("TOPPADDING", (0, 0), (-1, -1), 6),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
            ]
        )
    )
    story.append(table)
    document.build(story)
    filename = (
        f"drawlist-{int(drawlist.denomination)}-"
        f"{drawlist.draw_date.isoformat()}.pdf"
    )
    return Response(
        content=buffer.getvalue(),
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.get(
    path="/schedule",
    response_model=list[responses.UpcomingDrawInfo],
    summary="Fetch upcoming draw schedules",
)
async def get_upcoming_draws(
    admin: Annotated[models.AdminInfo, Depends(get_current_admin)],
) -> list[responses.UpcomingDrawInfo]:
    """Return all scheduled draws that have not yet passed in Pakistan time."""
    records = await DB.fetch(
        """
        SELECT "draw_date", "denomination", "created_at", COALESCE("location", 'State Bank of Pakistan (SBP)') AS "location"
        FROM "upcoming_draws"
        WHERE "draw_date" >= (
            CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Karachi'
        )::date
        ORDER BY "draw_date" ASC, "denomination" ASC
        """
    )
    return [
        responses.UpcomingDrawInfo(**record)
        for record in records
    ]


@router.post(
    path="/schedule",
    response_model=responses.UpcomingDrawInfo,
    status_code=status.HTTP_201_CREATED,
    summary="Add an upcoming draw to the schedule",
)
async def add_upcoming_draw(
    admin: Annotated[models.AdminInfo, Depends(get_current_admin)],
    payload: payloads.UpcomingDrawCreate,
) -> responses.UpcomingDrawInfo:
    """Add a future schedule entry; denomination/date pairs must be unique."""
    today_in_pakistan = datetime.now(PAKISTAN_STANDARD_TIME).date()
    if payload.draw_date <= today_in_pakistan:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="The scheduled draw date must be in the future.",
        )

    record = await DB.fetchrow(
        """
        INSERT INTO "upcoming_draws" ("draw_date", "denomination")
        VALUES ($1, $2)
        ON CONFLICT ("draw_date", "denomination") DO NOTHING
        RETURNING "draw_date", "denomination", "created_at"
        """,
        payload.draw_date,
        payload.denomination,
    )
    if record is None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="A schedule entry already exists for this denomination and date.",
        )
    return responses.UpcomingDrawInfo(**record)


@router.delete(
    path="/schedule/{denomination}/{draw_date}",
    response_model=responses.BaseResponse,
    summary="Delete an upcoming draw from the schedule",
)
async def delete_upcoming_draw(
    denomination: PrizeBondDenominations,
    draw_date: date,
    admin: Annotated[models.AdminInfo, Depends(get_current_admin)],
) -> responses.BaseResponse:
    """Delete one schedule entry by its denomination and draw date."""
    deleted_record = await DB.fetchrow(
        """
        DELETE FROM "upcoming_draws"
        WHERE "draw_date" = $1 AND "denomination" = $2
        RETURNING "draw_date"
        """,
        draw_date,
        denomination,
    )
    if deleted_record is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Upcoming draw schedule entry not found.",
        )
    return responses.BaseResponse(message="Upcoming draw removed from schedule.")


@router.post(
    path="",
    response_model= responses.BaseResponse,
    summary="Add a new drawlist.",
    status_code=status.HTTP_201_CREATED,
)
async def add_new_drawlist(
    admin: Annotated[models.AdminInfo, Depends(get_current_admin)],
    denomination: Annotated[PrizeBondDenominations, Form(...)],
    draw_date: Annotated[date, Form(...)],
    file: Annotated[UploadFile, File(...)],
) -> responses.BaseResponse:
    """Validate and import a text draw list provided by an administrator."""
    try:
        filename = file.filename or ""
        if Path(filename).suffix.casefold() != ".txt":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Only .txt draw-list files can be uploaded.",
            )

        content = await file.read()
        if not content:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="The uploaded draw-list file is empty.",
            )
        try:
            result = parse_text_draw_result(
                content,
                int(denomination),
                draw_date,
                source="admin-upload",
            )
        except ValueError as error:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=str(error),
            ) from error

        imported_count = await import_text_draw_result(result, DB)
        if imported_count is None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=(
                    "A draw result for this denomination and date already exists."
                ),
            )
        removed_tasks = await remove_completed_drawlist_tasks(DB)
    finally:
        await file.close()

    return responses.BaseResponse(
        status_code=status.HTTP_201_CREATED,
        message=(
            f"Imported {imported_count} winning bonds for the "
            f"{denomination} denomination draw dated {draw_date}. "
            f"Removed {removed_tasks} completed admin task(s)."
        )
    )