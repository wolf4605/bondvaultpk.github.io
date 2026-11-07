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
from pathlib import Path
from typing import Annotated

from fastapi import APIRouter, Depends, File, Form, UploadFile, status
from starlette.exceptions import HTTPException

from .. import models, payloads, responses
from ..configs import PrizeBondDenominations
from ..database import DB
from ..services.drawlist_automation import PAKISTAN_STANDARD_TIME
from ..services.drawlist_import import (
    import_text_draw_result,
    parse_text_draw_result,
    remove_completed_drawlist_tasks,
)
from ..utilities.auth_dependencies import get_current_admin

router = APIRouter(
    prefix = "/drawlists",
    tags = ["Drawlists"]
)


@router.get(
    path="/schedule",
    response_model=list[responses.UpcomingDrawInfo],
    summary="Fetch upcoming draw schedules",
)
async def get_upcoming_draws() -> list[responses.UpcomingDrawInfo]:
    """Return all scheduled draws that have not yet passed in Pakistan time."""
    records = await DB.fetch(
        """
        SELECT "draw_date", "denomination", "created_at"
        FROM "upcoming_draws"
        WHERE "draw_date" > (
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