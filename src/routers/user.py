"""
* Project Name: BONDVAULT PK

* Description: 

* Author: Wolf4605
* Email: mab4605@gmail.com

* Date: 2026-10-30 08:02:01

* Last Modified by: Wolf4605
* Last Modified time: 2026-10-30 08:02:02

* License: MIT
* Copyright© BondVault PK. All rights reserved.
"""

from typing import Annotated

from fastapi import APIRouter, Depends, status
from starlette.exceptions import HTTPException

from .. import models, payloads, responses
from ..database import DB
from ..utilities.auth_dependencies import get_current_user

router = APIRouter(
    prefix="/user",
    tags= ["Users"]
)

@router.get(
    path = "",
    response_model=responses.UserInfoResponse,
    response_description="The profile info of the logged in user.",
    summary="Get User Profile"
)
async def _get_profile(user:Annotated[models.UserInfo, Depends(get_current_user)]) -> responses.UserInfoResponse:
    """Fetch the Users Profile Info From the DB."""
    return responses.UserInfoResponse(
        message = "OK",
        user_info = user
    )


@router.patch(
    path="",
    summary="Update User Info",
    response_model=responses.BaseResponse
)
async def _update_user_info(
    user: Annotated[models.UserInfo, Depends(get_current_user)],
    payload: payloads.UserInfoUpdate,
):

    ALLOWED_UPDATE_FIELDS = {
        "username",
        "email",
        "first_name",
        "last_name",
        "contact",
        }

    raw_updates = payload.model_dump(exclude_unset=True, exclude_none=True)


    fields_to_update = {}
    for field, new_value in raw_updates.items():
        if field in ALLOWED_UPDATE_FIELDS and getattr(user, field, None) != new_value:
            fields_to_update[field] = new_value
    if not fields_to_update:
        raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail="No valid or changed fields were provided for update.",
        )
    set_clause = [
        f"{field} = ${i}"
        for i, field in enumerate(fields_to_update.keys(), start=2)
        ]
    query = (
        f"UPDATE users SET {', '.join(set_clause)} WHERE id = $1 RETURNING *"
        )
    values = [user.id] + list(fields_to_update.values())

    await DB.execute(query, *values)
    updated_fields_list = list(fields_to_update.keys())
   
    return responses.BaseResponse(
    message=f"Successfully updated fields: {', '.join(updated_fields_list)}"
    )