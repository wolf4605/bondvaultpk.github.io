"""
* Project Name: BONDVAULT PK

* Description: 

* Author: Wolf4605
* Email: mab4605@gmail.com

* Date: 2026-10-23 11:19:18

* Last Modified by: Wolf4605
* Last Modified time: 2026-10-23 13:41:38

* License: MIT
* Copyright© BondVault PK. All rights reserved.
""""""Administrator login and authenticated profile endpoints."""

import logging
import hashlib
import hmac
import secrets
from typing import Annotated
from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, Request, Response, status
from fastapi.security import OAuth2PasswordRequestForm
from starlette.exceptions import HTTPException

from .. import models, payloads, responses
from ..database import DB
from ..utilities.auth import hash_password, verify_password
from ..utilities.auth_dependencies import (
    clear_access_token_headers,
    get_current_admin,
    revoke_sessions,
)
from ..utilities.auth_tokens import create_access_token, token_lifetime
from ..services.email_service import (
    ADMIN_INVITE_EXPIRY_HOURS,
    send_admin_invitation_email,
)

logger = logging.getLogger("application.audit")
router = APIRouter(prefix="/admins",
                   tags=["Admin Authentication"])


@router.post(
    path="",
    response_model=models.AdminInfo,
    status_code=status.HTTP_201_CREATED,
    summary="Create an administrator account",
)
async def register_admin(
    admin: Annotated[models.AdminInfo, Depends(get_current_admin)],
    payload: payloads.AdminCreate,
) -> models.AdminInfo:
    """Create an admin and email a one-time password-setup invitation."""
    if not admin.is_superuser:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only a superuser can create administrator accounts.",
        )

    invite_token = secrets.token_urlsafe(32)
    token_hash = hashlib.sha256(invite_token.encode("utf-8")).hexdigest()
    random_password_hash = hash_password(secrets.token_urlsafe(48))
    invite_expires_at = datetime.now(UTC) + timedelta(
        hours=ADMIN_INVITE_EXPIRY_HOURS
    )
    async with DB.transaction() as connection:
        record = await connection.fetchrow(
            """
            INSERT INTO "admins" (
                "username", "password_hash", "email", "first_name",
                "last_name", "is_superuser"
            )
            VALUES ($1, $2, $3, $4, $5, FALSE)
            RETURNING "id", "username", "email", "first_name", "last_name",
                      "contact", "created_at", "is_superuser"
            """,
            payload.username,
            random_password_hash,
            str(payload.email),
            payload.first_name,
            payload.last_name,
        )
        if record is None:
            raise RuntimeError("The administrator account was not created.")
        await connection.execute(
            """
            INSERT INTO "admin_invites" ("admin_id", "token_hash", "expires_at")
            VALUES ($1, $2, $3)
            """,
            record["id"],
            token_hash,
            invite_expires_at,
        )

    logger.info(
        "administrator invitation created",
        extra={
            "event": "admin.invitation.created",
            "subject_id": str(record["id"]),
            "actor_id": str(admin.id),
        },
    )
    try:
        await send_admin_invitation_email(
            payload.email,
            payload.username,
            invite_token,
        )
    except RuntimeError as error:
        logger.exception(
            "administrator created but invitation email failed",
            extra={"event": "admin.invitation.email_failed"},
        )
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=(
                f"Administrator {record['id']} was created, but the invitation "
                "email could not be sent. Retry with "
                f"POST /admins/{record['id']}/invite."
            ),
        ) from error

    return models.AdminInfo.model_validate(dict(record))


@router.post(
    "/{admin_id}/invite",
    response_model=responses.BaseResponse,
    summary="Resend an administrator activation invitation",
)
async def resend_admin_invitation(
    admin_id: UUID,
    admin: Annotated[models.AdminInfo, Depends(get_current_admin)],
) -> responses.BaseResponse:
    """Rotate and resend an activation token for a pending administrator."""
    if not admin.is_superuser:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only a superuser can resend administrator invitations.",
        )

    invite_token = secrets.token_urlsafe(32)
    token_hash = hashlib.sha256(invite_token.encode("utf-8")).hexdigest()
    invite_expires_at = datetime.now(UTC) + timedelta(
        hours=ADMIN_INVITE_EXPIRY_HOURS
    )
    async with DB.transaction() as connection:
        record = await connection.fetchrow(
            """
            SELECT a."email", a."username"
            FROM "admins" AS a
            JOIN "admin_invites" AS i ON i."admin_id" = a."id"
            WHERE a."id" = $1
            FOR UPDATE OF i
            """,
            admin_id,
        )
        if record is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Pending administrator invitation not found.",
            )
        await connection.execute(
            """
            UPDATE "admin_invites"
            SET "token_hash" = $1, "expires_at" = $2, "created_at" = CURRENT_TIMESTAMP
            WHERE "admin_id" = $3
            """,
            token_hash,
            invite_expires_at,
            admin_id,
        )

    try:
        await send_admin_invitation_email(
            record["email"],
            record["username"],
            invite_token,
        )
    except RuntimeError as error:
        logger.exception(
            "administrator invitation resend failed",
            extra={"event": "admin.invitation.email_failed"},
        )
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="The invitation token was rotated, but its email could not be sent.",
        ) from error

    return responses.BaseResponse(message="Administrator invitation sent.")


@router.post(
    "/auth/activate",
    response_model=responses.BaseResponse,
    summary="Set a password using a one-time administrator invitation",
)
async def activate_admin_account(
    payload: payloads.AdminActivate,
) -> responses.BaseResponse:
    """Consume an unexpired invitation and set the administrator's password."""
    supplied_token_hash = hashlib.sha256(payload.token.encode("utf-8")).hexdigest()

    async with DB.transaction() as connection:
        record = await connection.fetchrow(
            """
            SELECT i."admin_id", i."token_hash"
            FROM "admin_invites" AS i
            JOIN "admins" AS a ON a."id" = i."admin_id"
            WHERE LOWER(a."email") = LOWER($1)
              AND i."expires_at" > CURRENT_TIMESTAMP
            FOR UPDATE OF i
            """,
            str(payload.email),
        )
        if record is None or not hmac.compare_digest(
            record["token_hash"].strip(),
            supplied_token_hash,
        ):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="The administrator invitation is invalid or expired.",
            )

        new_password_hash = hash_password(payload.new_password.get_secret_value())
        await connection.execute(
            'UPDATE "admins" SET "password_hash" = $1 WHERE "id" = $2',
            new_password_hash,
            record["admin_id"],
        )
        await connection.execute(
            'DELETE FROM "admin_invites" WHERE "admin_id" = $1',
            record["admin_id"],
        )

    return responses.BaseResponse(
        message="Administrator account activated. You can now sign in."
    )


@router.post(
    "/auth/login",
    response_model= responses.AdminLoginResponse,
    summary="Log in as an administrator",
)
async def login_admin(
    credentials: Annotated[OAuth2PasswordRequestForm, Depends()],
    request: Request,
) -> responses.AdminLoginResponse:
    """Authenticate an administrator with username/email and password form data."""
    record = await DB.fetchrow(
        """
        SELECT "id", "username", "email", "password_hash", "first_name",
               "last_name", "contact", "created_at", "is_superuser"
        FROM "admins"
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
            "administrator authentication failed",
            extra={"event": "auth.login.failed", "role": "admin"},
        )
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    admin = models.AdminInfo.model_validate(dict(record))
    session_id = uuid4()
    lifetime_seconds = int(token_lifetime().total_seconds())
    async with DB.transaction() as connection:
        current_password_hash = await connection.fetchval(
            'SELECT "password_hash" FROM "admins" WHERE "id" = $1 FOR UPDATE',
            admin.id,
        )
        if current_password_hash != record["password_hash"]:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid username or password.",
                headers={"WWW-Authenticate": "Bearer"},
            )
        await request.app.state.redis_wrapper.create_session(
            admin.id,
            "admin",
            session_id,
            lifetime_seconds,
        )

    token = create_access_token(admin.id, "admin", session_id)
    logger.info(
        "administrator authenticated",
        extra={
            "event": "auth.login.success",
            "role": "admin",
            "subject_id": str(admin.id),
        },
    )
    return responses.AdminLoginResponse(
        access_token=token,
        expires_in=lifetime_seconds,
        payload=admin,
    )


@router.post(
    "/auth/logout",
    response_model=responses.BaseResponse,
    summary="Log out the authenticated administrator",
)
async def logout_admin(
    admin: Annotated[models.AdminInfo, Depends(get_current_admin)],
    request: Request,
    response: Response,
) -> responses.BaseResponse:
    """Revoke the authenticated administrator's current session."""
    await revoke_sessions(
        admin.id,
        "admin",
        request.app.state.redis_wrapper,
        request.state.session_id,
    )
    clear_access_token_headers(response)
    logger.info(
        "administrator logged out",
        extra={
            "event": "auth.logout",
            "role": "admin",
            "subject_id": str(admin.id),
        },
    )
    return responses.BaseResponse(message="Logged out successfully.")


@router.get(
    "/me",
    response_model=models.AdminInfo,
    summary="Get the authenticated administrator's profile",
)
async def get_admin_info(
    admin_info: Annotated[models.AdminInfo, Depends(get_current_admin)],
) -> models.AdminInfo:
    """Return the authenticated administrator's profile without a separate ID."""
    return admin_info

@router.post(
    "/change-password",
    response_model=responses.BaseResponse,
    summary="Change the authenticated administrator's password",
)
async def change_password(
    admin: Annotated[models.AdminInfo, Depends(get_current_admin)],
    payload: payloads.ChangePassword,
    response: Response,
    request: Request,
) -> responses.BaseResponse:
    """Change the administrator's password and revoke all their sessions."""

    if payload.old_password == payload.new_password:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Old and new passwords cannot be the same.",
        )

    async with DB.transaction() as connection:
        old_password_hash = await connection.fetchval(
            'SELECT "password_hash" FROM "admins" WHERE "id" = $1 FOR UPDATE',
            admin.id,
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
            'UPDATE "admins" SET "password_hash" = $1 WHERE "id" = $2',
            new_password_hash,
            admin.id,
        )
        await revoke_sessions(admin.id, "admin", request.app.state.redis_wrapper)

    clear_access_token_headers(response)
    logger.info(
        "administrator password changed",
        extra={
            "event": "auth.password.changed",
            "role": "admin",
            "subject_id": str(admin.id),
        },
    )
    return responses.BaseResponse(message="Password changed successfully.")



__all__ = ["router"]
