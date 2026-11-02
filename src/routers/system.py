"""
* Project Name: BONDVAULT PK

* Description: 

* Author: Wolf4605
* Email: mab4605@gmail.com

* Date: 2026-10-30 09:45:18

* Last Modified by: Wolf4605
* Last Modified time: 2026-10-30 09:47:00

* License: MIT
* Copyright© BondVault PK. All rights reserved.
"""

from fastapi import APIRouter, Request

from .. import responses
from ..database import DB

router = APIRouter(
    prefix = "/system",
    tags = ["System"]
)


@router.get(
    path="/active-users",
    response_model=responses.ActiveUsersResponse,
    summary="Get registered and currently online user counts",
)
async def get_active_users(request: Request) -> responses.ActiveUsersResponse:
    """Return all registered users and distinct users with a live session."""
    active_user_ids = await request.app.state.redis_wrapper.get_active_user_ids()
    counts = await DB.fetchrow(
        """
        SELECT
            COUNT(*) AS "total_registered_users",
            COUNT(*) FILTER (
                WHERE "id" = ANY($1::UUID[])
            ) AS "currently_online_users"
        FROM "users"
        """,
        list(active_user_ids),
    )
    if counts is None:
        raise RuntimeError("The user count query returned no result.")

    return responses.ActiveUsersResponse(
        total_registered_users=counts["total_registered_users"],
        currently_online_users=counts["currently_online_users"],
    )


@router.get(
        path = "",
        )
async def get_health() -> None:
    """Return the existing health-check response."""
    raise TypeError("Unknown Value")
