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
import secrets
from typing import Annotated
from uuid import uuid4

from fastapi import APIRouter, Depends, Request, Response, status
from fastapi.security import OAuth2PasswordRequestForm
from redis.exceptions import RedisError
from starlette.exceptions import HTTPException

from .. import payloads, responses
from ..database import DB
from ..models.user_model import UserInfo, UserRegister
from ..services.email_service import EmailDeliveryError, send_password_recovery_email
from ..utilities.auth import hash_password, verify_password
from ..utilities.auth_dependencies import (
    clear_access_token_headers,
    get_current_user,
    revoke_sessions,
)
from ..utilities.auth_tokens import create_access_token, token_lifetime

logger = logging.getLogger("application.audit")
router = APIRouter(prefix="/users", tags=["User Authentication"])

PASSWORD_RECOVERY_RESPONSE_MESSAGE = (
    "If an eligible account exists for that email address, "
    "a recovery code has been sent."
)


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
               "last_name", "contact", "city", "address", "created_at",
               "is_verified", "verified_by", "last_login"
        FROM "users"
        WHERE ("username" = $1 OR LOWER("email") = LOWER($1))
          AND NOT EXISTS (
              SELECT 1
              FROM "blacklist"
              WHERE ("blacklist"."email" = "users"."email"
                     OR "blacklist"."contact" = "users"."contact")
                AND (
                    "blacklist"."duration" IS NULL
                    OR "blacklist"."duration" > CURRENT_TIMESTAMP
                )
          )
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


@router.post(
    "/auth/password-recovery",
    response_model=responses.BaseResponse,
    status_code=status.HTTP_202_ACCEPTED,
    summary="Request a user password recovery code",
)
async def request_password_recovery(
    payload: payloads.UserPasswordRecoveryRequest,
    request: Request,
) -> responses.BaseResponse:
    """Email a recovery code without revealing whether the account exists."""
    redis_wrapper = getattr(request.app.state, "redis_wrapper", None)
    if redis_wrapper is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Password recovery is temporarily unavailable.",
        )

    try:
        user = await DB.fetchrow(
            """
            SELECT "email"
            FROM "users"
            WHERE LOWER("email") = LOWER($1)
              AND "is_verified" IS TRUE
              AND NOT EXISTS (
                  SELECT 1
                  FROM "blacklist"
                  WHERE ("blacklist"."email" = "users"."email"
                         OR "blacklist"."contact" = "users"."contact")
                    AND (
                        "blacklist"."duration" IS NULL
                        OR "blacklist"."duration" > CURRENT_TIMESTAMP
                    )
              )
            """,
            str(payload.email),
        )
        client_ip = request.client.host if request.client is not None else "unknown"
        code = f"{secrets.randbelow(1_000_000):06d}"
        result = await redis_wrapper.create_email_verification_code(
            str(payload.email),
            code,
            client_ip,
            purpose="password-recovery",
        )
    except (ConnectionError, RedisError, OSError, TimeoutError) as error:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Password recovery is temporarily unavailable.",
        ) from error

    if result in {1, 2}:
        retry_after = (
            redis_wrapper.PASSWORD_RECOVERY_RESEND_SECONDS
            if result == 1
            else redis_wrapper.PASSWORD_RECOVERY_IP_WINDOW_SECONDS
        )
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many recovery requests. Please try again later.",
            headers={"Retry-After": str(retry_after)},
        )
    if result != 0:
        raise RuntimeError("The password recovery code could not be stored.")

    if user is not None:
        try:
            await send_password_recovery_email(user["email"], code)
        except EmailDeliveryError:
            await redis_wrapper.discard_email_verification_code(
                str(payload.email),
                purpose="password-recovery",
            )
            raise
    else:
        await redis_wrapper.discard_email_verification_code(
            str(payload.email),
            purpose="password-recovery",
        )

    return responses.BaseResponse(
        status_code=status.HTTP_202_ACCEPTED,
        message=PASSWORD_RECOVERY_RESPONSE_MESSAGE,
    )


@router.post(
    "/auth/password-recovery/complete",
    response_model=responses.BaseResponse,
    summary="Reset a user password with a recovery code",
)
async def complete_password_recovery(
    payload: payloads.UserPasswordRecoveryComplete,
    request: Request,
) -> responses.BaseResponse:
    """Consume a recovery code, change the password, and revoke user sessions."""
    redis_wrapper = getattr(request.app.state, "redis_wrapper", None)
    if redis_wrapper is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Password recovery is temporarily unavailable.",
        )

    try:
        async with DB.transaction() as connection:
            user = await connection.fetchrow(
                """
                SELECT "id"
                FROM "users"
                WHERE LOWER("email") = LOWER($1)
                  AND "is_verified" IS TRUE
                  AND NOT EXISTS (
                      SELECT 1
                      FROM "blacklist"
                      WHERE ("blacklist"."email" = "users"."email"
                             OR "blacklist"."contact" = "users"."contact")
                        AND (
                            "blacklist"."duration" IS NULL
                            OR "blacklist"."duration" > CURRENT_TIMESTAMP
                        )
                  )
                FOR UPDATE
                """,
                str(payload.email),
            )
            if user is None:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="The recovery code is invalid or expired.",
                )

            is_valid_code = await redis_wrapper.verify_email_verification_code(
                str(payload.email),
                payload.code,
                purpose="password-recovery",
            )
            if not is_valid_code:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="The recovery code is invalid or expired.",
                )

            await connection.execute(
                'UPDATE "users" SET "password_hash" = $1 WHERE "id" = $2',
                hash_password(payload.new_password),
                user["id"],
            )
            await revoke_sessions(user["id"], "user", redis_wrapper)
    except (ConnectionError, RedisError, OSError, TimeoutError) as error:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Password recovery is temporarily unavailable.",
        ) from error

    logger.info(
        "user password recovered",
        extra={
            "event": "auth.password.recovered",
            "role": "user",
            "subject_id": str(user["id"]),
        },
    )
    return responses.BaseResponse(
        message="Password reset successfully. Please sign in with your new password."
    )


@router.post(
    "/auth/register",
    response_model=responses.UserInfoResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Register a new user account",
)
async def register_user(
    payload: UserRegister,
) -> responses.UserInfoResponse:
    """Register a new user in the application."""
    existing = await DB.fetchval(
        'SELECT 1 FROM "users" WHERE "username" = $1 OR "email" = $2',
        payload.username,
        payload.email,
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Username or email is already registered.",
        )

    record = await DB.fetchrow(
        """
        INSERT INTO "users" (
            "username", "email", "password_hash", "first_name",
            "last_name", "contact", "city", "address", "is_verified"
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, FALSE)
        RETURNING "id", "username", "email", "first_name", "last_name",
                  "contact", "city", "address", "created_at", "is_verified",
                  "verified_by", "last_login"
        """,
        payload.username,
        payload.email,
        payload.password_hash,
        payload.first_name,
        payload.last_name,
        payload.contact,
        payload.city,
        payload.address,
    )
    if record is None:
        raise RuntimeError("User registration failed.")

    user = UserInfo.model_validate(dict(record))
    logger.info(
        "user registered",
        extra={
            "event": "auth.register.success",
            "role": "user",
            "subject_id": str(user.id),
        },
    )
    return responses.UserInfoResponse(
        message="User registered successfully.",
        user_info=user,
    )


@router.get(
    "/auth/check-availability",
    summary="Check if username, email, or contact is available and not blacklisted",
)
async def check_availability(
    username: str | None = None,
    email: str | None = None,
    contact: str | None = None,
) -> dict:
    """Check availability of username, email, or contact against users and blacklist tables."""
    username_taken = False
    email_taken = False
    contact_taken = False

    if username:
        username_exists = await DB.fetchval(
            'SELECT 1 FROM "users" WHERE "username" = $1',
            username,
        )
        username_taken = username_exists is not None

    if email:
        email_lower = email.lower()
        user_exists = await DB.fetchval(
            'SELECT 1 FROM "users" WHERE LOWER("email") = $1',
            email_lower,
        )
        blacklist_exists = await DB.fetchval(
            """
            SELECT 1 FROM "blacklist"
            WHERE LOWER("email") = $1
              AND ("duration" IS NULL OR "duration" > CURRENT_TIMESTAMP)
            """,
            email_lower,
        )
        email_taken = (user_exists is not None) or (blacklist_exists is not None)

    if contact:
        if contact.startswith("0"):
            contact = contact.replace("0","+92", 1)
        user_exists = await DB.fetchval(
            'SELECT 1 FROM "users" WHERE "contact" = $1',
            contact,
        )
        blacklist_exists = await DB.fetchval(
            """
            SELECT 1 FROM "blacklist"
            WHERE "contact" = $1
              AND ("duration" IS NULL OR "duration" > CURRENT_TIMESTAMP)
            """,
            contact,
        )
        contact_taken = (user_exists is not None) or (blacklist_exists is not None)

    return {
        "username_taken": username_taken,
        "email_taken": email_taken,
        "contact_taken": contact_taken,
    }



__all__ = ["router"]
