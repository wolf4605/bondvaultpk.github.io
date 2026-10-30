"""
* Project Name: BONDVAULT PK

* Description: 

* Author: Wolf4605
* Email: mab4605@gmail.com

* Date: 2026-10-28 10:57:05

* Last Modified by: Wolf4605
* Last Modified time: 2026-10-28 10:57:20

* License: MIT
* Copyright© BondVault PK. All rights reserved.
"""

from typing import Annotated

from fastapi import APIRouter, Depends, status
from starlette.exceptions import HTTPException

from .. import models, payloads, responses
from ..database import DB
from ..utilities.auth import hash_password, verify_password
from ..utilities.auth_dependencies import get_current_admin

router = APIRouter(prefix="/admins",
                   tags=["Administrators"])
@router.get(
    '/users',
    response_model= responses.AllUsersResponse,
    summary="Fetch all users."
)
async def fetch_all(admin: Annotated[models.AdminInfo, Depends(get_current_admin)],):
    """Returns a list of all the users along with their info."""

    query = """
            SELECT * FROM "users"
            """
    records = await DB.fetch(query)

    users = []
    if records:
        for record in records:
            users.append(models.UserInfo(**dict(record)))

    return responses.AllUsersResponse(
        message= f"Found {len(users)} users.",
        users=users
    )

