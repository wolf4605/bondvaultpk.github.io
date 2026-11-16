"""
* Project Name: BONDVAULT PK
* Description: Interactive support reporting and ticketing system endpoints for users and administrators.
* Author: Wolf4605
* Email: mab4605@gmail.com
* Date: 2026-11-16 14:15:00
* License: MIT
* Copyright© BondVault PK. All rights reserved.
"""

import asyncio
import logging
from typing import Annotated, Literal
from uuid import UUID

from fastapi import APIRouter, Depends, Query, status
from starlette.exceptions import HTTPException

from .. import models, payloads, responses
from ..database import DB
from ..services.email_service import send_user_action_email
from ..utilities.auth_dependencies import get_current_admin, get_current_user

logger = logging.getLogger("application.audit")

user_router = APIRouter(
    prefix="/user/reports",
    tags=["User Support Reports"],
)

admin_router = APIRouter(
    prefix="/admins/reports",
    tags=["Admin Support Reports"],
)


@user_router.post(
    "",
    response_model=responses.ReportInfo,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new support report ticket",
)
async def create_user_report(
    user: Annotated[models.UserInfo, Depends(get_current_user)],
    payload: payloads.UserReportCreate,
) -> responses.ReportInfo:
    """Create a new support report and append the initial issue message."""
    async with DB.transaction() as conn:
        report = await conn.fetchrow(
            """
            INSERT INTO "reports" ("reported_by", "subject", "category", "content", "status")
            VALUES ($1, $2, $3, $4, 'open')
            RETURNING "id", "reported_by", "subject", "category", "content", "status", "created_at", "updated_at", "closed_at", "closed_by"
            """,
            user.id,
            payload.subject.strip(),
            payload.category.strip().lower(),
            payload.content.strip(),
        )
        if report is None:
            raise RuntimeError("Report ticket creation failed.")

        sender_name = f"{user.first_name or ''} {user.last_name or ''}".strip() or user.username
        await conn.execute(
            """
            INSERT INTO "report_messages" ("report_id", "sender_id", "sender_type", "sender_name", "message")
            VALUES ($1, $2, 'user', $3, $4)
            """,
            report["id"],
            user.id,
            sender_name,
            payload.content.strip(),
        )

    res_dict = dict(report)
    res_dict["message_count"] = 1
    return responses.ReportInfo.model_validate(res_dict)


@user_router.get(
    "",
    response_model=list[responses.ReportInfo],
    summary="Fetch all support reports created by the user",
)
async def get_user_reports(
    user: Annotated[models.UserInfo, Depends(get_current_user)],
) -> list[responses.ReportInfo]:
    """Return all support report tickets opened by the authenticated user."""
    records = await DB.fetch(
        """
        SELECT r."id", r."reported_by", r."subject", r."category", r."content", r."status",
               r."created_at", r."updated_at", r."closed_at", r."closed_by",
               COUNT(m."id")::INT AS "message_count"
        FROM "reports" AS r
        LEFT JOIN "report_messages" AS m ON m."report_id" = r."id"
        WHERE r."reported_by" = $1
        GROUP BY r."id"
        ORDER BY r."updated_at" DESC
        """,
        user.id,
    )
    return [responses.ReportInfo.model_validate(dict(rec)) for rec in records]


@user_router.get(
    "/{report_id}/messages",
    response_model=list[responses.ReportMessageInfo],
    summary="Fetch message thread for a user support report",
)
async def get_user_report_messages(
    report_id: UUID,
    user: Annotated[models.UserInfo, Depends(get_current_user)],
) -> list[responses.ReportMessageInfo]:
    """Return the complete chat message thread for a report ticket."""
    report = await DB.fetchrow(
        'SELECT "id" FROM "reports" WHERE "id" = $1 AND "reported_by" = $2',
        report_id,
        user.id,
    )
    if report is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Support report ticket not found.",
        )

    records = await DB.fetch(
        """
        SELECT "id", "report_id", "sender_id", "sender_type", "sender_name", "message", "created_at"
        FROM "report_messages"
        WHERE "report_id" = $1
        ORDER BY "created_at" ASC
        """,
        report_id,
    )
    return [responses.ReportMessageInfo.model_validate(dict(rec)) for rec in records]


@user_router.post(
    "/{report_id}/messages",
    response_model=responses.ReportMessageInfo,
    status_code=status.HTTP_201_CREATED,
    summary="Send a chat message in a support report thread",
)
async def add_user_report_message(
    report_id: UUID,
    payload: payloads.ReportMessageCreate,
    user: Annotated[models.UserInfo, Depends(get_current_user)],
) -> responses.ReportMessageInfo:
    """Post a new message in an open support ticket chat thread."""
    report = await DB.fetchrow(
        'SELECT "id", "status" FROM "reports" WHERE "id" = $1 AND "reported_by" = $2',
        report_id,
        user.id,
    )
    if report is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Support report ticket not found.",
        )
    if report["status"] == "closed":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This support ticket has been closed and cannot receive new messages.",
        )

    sender_name = f"{user.first_name or ''} {user.last_name or ''}".strip() or user.username
    async with DB.transaction() as conn:
        msg = await conn.fetchrow(
            """
            INSERT INTO "report_messages" ("report_id", "sender_id", "sender_type", "sender_name", "message")
            VALUES ($1, $2, 'user', $3, $4)
            RETURNING "id", "report_id", "sender_id", "sender_type", "sender_name", "message", "created_at"
            """,
            report_id,
            user.id,
            sender_name,
            payload.message.strip(),
        )
        await conn.execute(
            'UPDATE "reports" SET "updated_at" = CURRENT_TIMESTAMP WHERE "id" = $1',
            report_id,
        )

    if msg is None:
        raise RuntimeError("Failed to post message.")
    return responses.ReportMessageInfo.model_validate(dict(msg))


# ================= ADMIN ENDPOINTS =================


@admin_router.get(
    "",
    response_model=list[responses.ReportInfo],
    summary="Fetch all support reports for administrator moderation",
)
async def get_admin_reports(
    admin: Annotated[models.AdminInfo, Depends(get_current_admin)],
    status_filter: str = Query(default="all", alias="status"),
) -> list[responses.ReportInfo]:
    """Return all support report tickets across all users."""
    where_clause = ""
    params = []
    if status_filter in {"open", "in_progress", "closed"}:
        where_clause = 'WHERE r."status" = $1'
        params.append(status_filter)

    records = await DB.fetch(
        f"""
        SELECT r."id", r."reported_by", r."subject", r."category", r."content", r."status",
               r."created_at", r."updated_at", r."closed_at", r."closed_by",
               u."username" AS "reporter_username", u."email" AS "reporter_email",
               COUNT(m."id")::INT AS "message_count"
        FROM "reports" AS r
        JOIN "users" AS u ON u."id" = r."reported_by"
        LEFT JOIN "report_messages" AS m ON m."report_id" = r."id"
        {where_clause}
        GROUP BY r."id", u."username", u."email"
        ORDER BY r."updated_at" DESC
        """,
        *params,
    )
    return [responses.ReportInfo.model_validate(dict(rec)) for rec in records]


@admin_router.get(
    "/{report_id}/messages",
    response_model=list[responses.ReportMessageInfo],
    summary="Fetch message thread for any support report (Admin)",
)
async def get_admin_report_messages(
    report_id: UUID,
    admin: Annotated[models.AdminInfo, Depends(get_current_admin)],
) -> list[responses.ReportMessageInfo]:
    """Return the complete chat message thread for an admin ticket moderation."""
    report = await DB.fetchrow('SELECT "id" FROM "reports" WHERE "id" = $1', report_id)
    if report is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Support report ticket not found.",
        )

    records = await DB.fetch(
        """
        SELECT "id", "report_id", "sender_id", "sender_type", "sender_name", "message", "created_at"
        FROM "report_messages"
        WHERE "report_id" = $1
        ORDER BY "created_at" ASC
        """,
        report_id,
    )
    return [responses.ReportMessageInfo.model_validate(dict(rec)) for rec in records]


@admin_router.post(
    "/{report_id}/messages",
    response_model=responses.ReportMessageInfo,
    status_code=status.HTTP_201_CREATED,
    summary="Reply as an administrator in a support report thread",
)
async def add_admin_report_message(
    report_id: UUID,
    payload: payloads.ReportMessageCreate,
    admin: Annotated[models.AdminInfo, Depends(get_current_admin)],
) -> responses.ReportMessageInfo:
    """Post an administrator reply in a support ticket chat thread."""
    report = await DB.fetchrow(
        'SELECT "id", "status", "reported_by" FROM "reports" WHERE "id" = $1',
        report_id,
    )
    if report is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Support report ticket not found.",
        )

    sender_name = f"Admin ({admin.first_name or admin.username})"
    async with DB.transaction() as conn:
        msg = await conn.fetchrow(
            """
            INSERT INTO "report_messages" ("report_id", "sender_id", "sender_type", "sender_name", "message")
            VALUES ($1, $2, 'admin', $3, $4)
            RETURNING "id", "report_id", "sender_id", "sender_type", "sender_name", "message", "created_at"
            """,
            report_id,
            admin.id,
            sender_name,
            payload.message.strip(),
        )
        new_status = "in_progress" if report["status"] == "open" else report["status"]
        await conn.execute(
            """
            UPDATE "reports"
            SET "status" = $1, "updated_at" = CURRENT_TIMESTAMP
            WHERE "id" = $2
            """,
            new_status,
            report_id,
        )

    if msg is None:
        raise RuntimeError("Failed to post admin reply.")
    return responses.ReportMessageInfo.model_validate(dict(msg))


@admin_router.patch(
    "/{report_id}/status",
    response_model=responses.BaseResponse,
    summary="Update or close a support report ticket status",
)
async def update_report_status(
    report_id: UUID,
    payload: payloads.AdminReportStatusUpdate,
    admin: Annotated[models.AdminInfo, Depends(get_current_admin)],
) -> responses.BaseResponse:
    """Update report ticket status ('closed', 'in_progress', 'open')."""
    report = await DB.fetchrow(
        """
        SELECT r."id", r."subject", u."email", u."username"
        FROM "reports" AS r
        JOIN "users" AS u ON u."id" = r."reported_by"
        WHERE r."id" = $1
        """,
        report_id,
    )
    if report is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Support report ticket not found.",
        )

    closed_at = "CURRENT_TIMESTAMP" if payload.status == "closed" else "NULL"
    closed_by_val = admin.id if payload.status == "closed" else None

    if payload.status == "closed":
        await DB.execute(
            """
            UPDATE "reports"
            SET "status" = 'closed', "closed_at" = CURRENT_TIMESTAMP, "closed_by" = $1, "updated_at" = CURRENT_TIMESTAMP
            WHERE "id" = $2
            """,
            admin.id,
            report_id,
        )
    else:
        await DB.execute(
            """
            UPDATE "reports"
            SET "status" = $1, "closed_at" = NULL, "closed_by" = NULL, "updated_at" = CURRENT_TIMESTAMP
            WHERE "id" = $2
            """,
            payload.status,
            report_id,
        )

    # Notify user via email on ticket resolution/status change
    async def _send_email():
        try:
            await send_user_action_email(
                report["email"],
                report["username"],
                "support ticket status update",
                f"Your support ticket '{report['subject']}' status was updated to '{payload.status.upper()}'.",
            )
        except Exception:
            logger.exception("ticket status update email failed")

    asyncio.create_task(_send_email())

    return responses.BaseResponse(
        message=f"Support ticket status updated to {payload.status.upper()}."
    )
