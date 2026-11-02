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
from uuid import uuid4

from fastapi import APIRouter, Depends, Request, Response, status
from fastapi.security import OAuth2PasswordRequestForm
from starlette.exceptions import HTTPException

from .. import payloads, responses
from ..database import DB
from ..models.user_model import UserInfo
from ..utilities.auth import hash_password, verify_password
from ..utilities.auth_dependencies import (
    clear_access_token_headers,
    get_current_user,
    revoke_sessions,
)
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
    request: Request,
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

    session_id = uuid4()
    lifetime_seconds = int(token_lifetime().total_seconds())
    async with DB.transaction() as connection:
        current_password_hash = await connection.fetchval(
            'SELECT "password_hash" FROM "users" WHERE "id" = $1 FOR UPDATE',
            user.id,
        )
        if current_password_hash != record["password_hash"]:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid username or password.",
                headers={"WWW-Authenticate": "Bearer"},
            )
        await request.app.state.redis_wrapper.create_session(
            user.id,
            "user",
            session_id,
            lifetime_seconds,
        )

    token = create_access_token(user.id, "user", session_id)
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
        expires_in=lifetime_seconds,
        payload=user,
    )


@router.post(
    "/auth/logout",
    response_model=responses.BaseResponse,
    summary="Log out the authenticated user",
)
async def logout_user(
    user: Annotated[UserInfo, Depends(get_current_user)],
    request: Request,
    response: Response,
) -> responses.BaseResponse:
    """Revoke the authenticated user's current session."""
    await revoke_sessions(
        user.id,
        "user",
        request.app.state.redis_wrapper,
        request.state.session_id,
    )
    clear_access_token_headers(response)
    logger.info(
        "user logged out",
        extra={
            "event": "auth.logout",
            "role": "user",
            "subject_id": str(user.id),
        },
    )
    return responses.BaseResponse(message="Logged out successfully.")


@router.post(
    "/change-password",
    response_model=responses.BaseResponse,
    summary="Change the authenticated user's password",
)
async def change_password(
    user: Annotated[UserInfo, Depends(get_current_user)],
    payload: payloads.ChangePassword,
    response: Response,
    request: Request,
) -> responses.BaseResponse:
    """Change the user's password and revoke all of their sessions."""

    if payload.old_password == payload.new_password:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Old and new passwords cannot be the same.",
        )

    async with DB.transaction() as connection:
        old_password_hash = await connection.fetchval(
            'SELECT "password_hash" FROM "users" WHERE "id" = $1 FOR UPDATE',
            user.id,
        )
        if not isinstance(old_password_hash, str) or not verify_password(
            payload.old_password,
            old_password_hash,
        ):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Invalid old password.",
            )

        new_password_hash = hash_password(payload.new_password)
        await connection.execute(
            'UPDATE "users" SET "password_hash" = $1 WHERE "id" = $2',
            new_password_hash,
            user.id,
        )
        await revoke_sessions(user.id, "user", request.app.state.redis_wrapper)

    clear_access_token_headers(response)
    logger.info(
        "user password changed",
        extra={
            "event": "auth.password.changed",
            "role": "user",
            "subject_id": str(user.id),
        },
    )
    return responses.BaseResponse(message="Password changed successfully.")



__all__ = ["router"]
