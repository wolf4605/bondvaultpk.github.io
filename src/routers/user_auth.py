"""
* Project Name: BONDVAULT PK

* Description: 

* Author: Wolf4605
* Email: mab4605@gmail.com

* Date: 2026-10-23 11:19:18

* Last Modified by: Wolf4605
* Last Modified time: 2026-10-23 13:41:14

* License: MIT
* Copyright© BondVault PK. All rights reserved.
""""""User login and authenticated profile endpoints."""

import logging
from typing import Annotated

from fastapi import APIRouter, Depends, status
from fastapi.security import OAuth2PasswordRequestForm
from starlette.exceptions import HTTPException

from .. import payloads, responses
from ..database import DB
from ..models.user_model import UserInfo
from ..utilities.auth import hash_password, verify_password
from ..utilities.auth_dependencies import get_current_user
from ..utilities.auth_tokens import create_access_token, token_lifetime

logger = logging.getLogger("application.audit")
router = APIRouter(prefix="/users", tags=["User Authentication"])


@router.post(
    "/auth/login",
    response_model=responses.UserLoginResponse,
    summary="Log in as a user",
)
async def login_user(
    credentials: Annotated[OAuth2PasswordRequestForm, Depends()],
) -> responses.UserLoginResponse:
    """Authenticate a user with an OAuth2 username/email and password form."""
    record = await DB.fetchrow(
        """
        SELECT "id", "username", "email", "password_hash", "first_name",
               "last_name", "contact", "created_at", "is_verified",
               "verified_by", "last_login"
        FROM "users"
        WHERE "username" = $1 OR LOWER("email") = LOWER($1)
        ORDER BY ("username" = $1) DESC
        LIMIT 1
        """,
        credentials.username,
    )
    if record is None or not verify_password(
        credentials.password,
        record["password_hash"],
    ):
        logger.warning(
            "user authentication failed",
            extra={"event": "auth.login.failed", "role": "user"},
        )
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user = UserInfo.model_validate(dict(record))
    if await DB.fetchval(
        """
        UPDATE "users"
        SET "last_login" = CURRENT_TIMESTAMP
        WHERE "id" = $1
        RETURNING TRUE
        """,
        user.id,
    ) is not True:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = create_access_token(user.id, "user")
    logger.info(
        "user authenticated",
        extra={
            "event": "auth.login.success",
            "role": "user",
            "subject_id": str(user.id),
        },
    )
    return responses.UserLoginResponse(
        access_token=token,
        expires_in=int(token_lifetime().total_seconds()),
        payload=user,
    )

@router.post(
    "/change-password",
    summary="Change Password"
)
async def change_password(
    user: Annotated[UserInfo, Depends(get_current_user)],
    payload: payloads.ChangePassword):
    """Request for a password change."""

    if payload.old_password == payload.new_password:
        return HTTPException(
            status_code= status.HTTP_409_CONFLICT,
            detail= "Old and New Passwords can not be the same."
        )

    old_password_hash = await DB.fetchval("""SELECT "password_hash" FROM "users" WHERE "id"= $1""",user.id)

    if not verify_password(payload.old_password, old_password_hash):
        return HTTPException(
            status_code= status.HTTP_403_FORBIDDEN,
            detail = "Invalid Old password"
        )
    
    new_password_hash = hash_password(payload.new_password)
    query = """
            UPDATE "users"
            SET "password_hash" = $1
            WHERE "id" = $2
        """
    await DB.execute(
        query,
        new_password_hash,
        user.id
    )
    return responses.BaseResponse(message="Password Change Successfully.")



__all__ = ["router"]
