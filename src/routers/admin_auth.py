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
from typing import Annotated

from fastapi import APIRouter, Depends, status
from fastapi.security import OAuth2PasswordRequestForm
from starlette.exceptions import HTTPException

from .. import models, payloads, responses
from ..database import DB
from ..utilities.auth import hash_password, verify_password
from ..utilities.auth_dependencies import get_current_admin
from ..utilities.auth_tokens import create_access_token, token_lifetime

logger = logging.getLogger("application.audit")
router = APIRouter(prefix="/admins",
                   tags=["Admin Authentication"])


@router.post(
        path = "",
        response_model = responses.AdminRegister,
        summary="Register an Admin",
        response_description="Details of the created administrator account."
)
async def register_admin(
    admin: Annotated[models.AdminInfo, get_current_admin],
    payload
):
    """Add a new admin account to the admins."""


@router.post(
    "/auth/login",
    response_model= responses.AdminLoginResponse,
    summary="Log in as an administrator",
)
async def login_admin(
    credentials: Annotated[OAuth2PasswordRequestForm, Depends()],
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
    token = create_access_token(admin.id, "admin")
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
        expires_in=int(token_lifetime().total_seconds()),
        payload=admin,
    )


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
    summary="Change Password"
)
async def change_password(
    admin: Annotated[models.AdminInfo, Depends(get_current_admin)],
    payload: payloads.ChangePassword):
    """Request for a password change."""

    if payload.old_password == payload.new_password:
        return HTTPException(
            status_code= status.HTTP_409_CONFLICT,
            detail= "Old and New Passwords can not be the same."
        )

    old_password_hash = await DB.fetchval("""SELECT "password_hash" FROM "users" WHERE "id"= $1""",admin.id)

    if not verify_password(payload.old_password, old_password_hash):
        return HTTPException(
            status_code= status.HTTP_403_FORBIDDEN,
            detail = "Invalid Old password"
        )
    else:
        new_password_hash = hash_password(payload.new_password)
        query = """
                UPDATE "users"
                SET "password_hash" = $1
                WHERE "id" = $2
            """
        await DB.execute(
            query,
            new_password_hash,
            admin.id
        )
        return responses.BaseResponse(message="Password Change Successfully.")



__all__ = ["router"]
