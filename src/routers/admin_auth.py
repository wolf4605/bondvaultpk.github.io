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

import asyncio
import logging
import secrets
from typing import Annotated
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, Request, Response, status
from fastapi.security import OAuth2PasswordRequestForm
from redis.exceptions import RedisError
from starlette.exceptions import HTTPException

from .. import models, payloads, responses
from ..database import DB
from ..payloads.basic import AdminSetAdminPassword
from ..services.email_service import (
    EmailDeliveryError,
    send_admin_deleted_email,
    send_admin_invitation_email,
    send_admin_password_changed_email,
    send_user_action_email,
)
from ..utilities.auth import hash_password, verify_password
from ..utilities.auth_dependencies import (
    clear_access_token_headers,
    get_current_admin,
    record_failed_login_attempt,
    revoke_sessions,
)
from ..utilities.auth_tokens import create_access_token, token_lifetime

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
    """Create an admin account, generate a random password, and email credentials to the administrator."""
    target_role = (payload.role or "admin").lower()
    if target_role not in ("admin", "superuser", "owner"):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Administrator role must be admin, superuser, or owner.",
        )

    if admin.role == "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only a superuser or system owner can create administrator accounts.",
        )

    if admin.role == "superuser" and target_role in ("superuser", "owner"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Superusers can only create normal administrator accounts. Only a System Owner can create superusers or owners.",
        )

    existing = await DB.fetchrow(
        'SELECT "username", "email" FROM "admins" WHERE LOWER("username") = LOWER($1) OR LOWER("email") = LOWER($2)',
        payload.username,
        str(payload.email),
    )
    if existing:
        if existing["username"].lower() == payload.username.lower():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Administrator username '@{payload.username}' is already taken.",
            )
        else:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"An administrator account with email '{payload.email}' already exists.",
            )

    generated_password = _generate_random_password()
    generated_pwd_hash = hash_password(generated_password)
    first_name_clean = payload.first_name.strip() if payload.first_name and payload.first_name.strip() else None
    last_name_clean = payload.last_name.strip() if payload.last_name and payload.last_name.strip() else None

    async with DB.transaction() as connection:
        record = await connection.fetchrow(
            """
            INSERT INTO "admins" (
                "username", "password_hash", "email", "first_name",
                "last_name", "role"
            )
            VALUES ($1, $2, $3, $4, $5, $6)
            RETURNING "id", "username", "email", "first_name", "last_name",
                      "contact", "created_at", "role"
            """,
            payload.username,
            generated_pwd_hash,
            str(payload.email),
            first_name_clean,
            last_name_clean,
            target_role,
        )
        if record is None:
            raise RuntimeError("The administrator account was not created.")

    logger.info(
        "administrator account created and credentials generated",
        extra={
            "event": "admin.account.created",
            "subject_id": str(record["id"]),
            "actor_id": str(admin.id),
        },
    )

    async def _send_email_async():
        try:
            await send_admin_invitation_email(
                payload.email,
                payload.username,
                generated_password,
                target_role,
            )
        except Exception:
            logger.exception("admin credentials email delivery failed")

    asyncio.create_task(_send_email_async())
    return models.AdminInfo.model_validate(dict(record))


@router.delete(
    "/{admin_id}",
    response_model=responses.BaseResponse,
    summary="Delete an administrator account",
)
async def delete_admin(
    admin_id: UUID,
    admin: Annotated[models.AdminInfo, Depends(get_current_admin)],
    request: Request,
) -> responses.BaseResponse:
    """Allow a superuser to delete another admin and revoke their sessions."""
    if not admin.role in ("superuser", "owner"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only a superuser can delete administrator accounts.",
        )
    if admin_id == admin.id:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="You cannot delete your own administrator account.",
        )

    async with DB.transaction() as connection:
        superusers = await connection.fetch(
            """
                SELECT "id"
                FROM "admins"
                WHERE "role" = 'superuser'
                ORDER BY "id"
                FOR UPDATE
            """
        )
        target = await connection.fetchrow(
            """
                SELECT "id", "username", "email", "role"
                FROM "admins"
                WHERE "id" = $1
                FOR UPDATE
            """,
            admin_id,
        )
        if target is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Administrator not found.",
            )

        if target["role"] == "owner":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="A system owner account cannot be deleted through this endpoint.",
            )

        if target["role"] == "superuser" and len(superusers) <= 1:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="The last superuser account cannot be deleted.",
            )

        deleted_admin_id = await connection.fetchval(
            """
            DELETE FROM "admins"
            WHERE "id" = $1
            RETURNING "id"
            """,
            admin_id,
        )
        if deleted_admin_id is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Administrator not found.",
            )

    logger.warning(
        "administrator account deleted",
        extra={
            "event": "admin.deleted",
            "subject_id": str(admin_id),
            "actor_id": str(admin.id),
        },
    )
    failures: list[str] = []
    try:
        await revoke_sessions(
            admin_id,
            "admin",
            request.app.state.redis_wrapper,
        )
    except (ConnectionError, RedisError, OSError, TimeoutError) as error:
        logger.exception(
            "administrator deleted but session revocation failed",
            extra={
                "event": "admin.session.revocation_failed",
                "subject_id": str(admin_id),
                "actor_id": str(admin.id),
            },
        )
        failures.append("active sessions could not be revoked")

    try:
        await send_admin_deleted_email(target["email"], target["username"])
    except EmailDeliveryError as error:
        logger.exception(
            "administrator deleted but notification email failed",
            extra={
                "event": "admin.deleted.email_failed",
                "subject_id": str(admin_id),
                "actor_id": str(admin.id),
            },
        )
        failures.append("the notification email could not be sent")

    if failures:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=(
                f"The administrator was deleted, but {' and '.join(failures)}. "
                "The deletion has already taken effect."
            ),
        )

    return responses.BaseResponse(
        message="Administrator deleted, notified, and active sessions revoked."
    )


@router.put(
    "/{admin_id}/password",
    response_model=responses.BaseResponse,
    summary="Reset password of an administrator account to a new random password",
)
async def set_admin_password(
    admin_id: UUID,
    admin: Annotated[models.AdminInfo, Depends(get_current_admin)],
    request: Request,
) -> responses.BaseResponse:
    """Allow a superuser or system owner to reset an admin's password to a random one and email it."""
    return await update_admin_password(admin_id, admin, request)


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
               "last_name", "contact", "created_at", COALESCE("role", 'admin') AS "role"
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
        await record_failed_login_attempt(
            request,
            "admin",
            str(record["id"]) if record is not None else credentials.username,
        )
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
            await record_failed_login_attempt(
                request,
                "admin",
                str(record["id"]),
            )
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
    request.state.admin_payload = admin
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



@router.get(
    "/accounts/all",
    response_model=list[models.AdminInfo],
    summary="Fetch all administrator accounts for management",
)
async def fetch_admin_accounts(
    admin: Annotated[models.AdminInfo, Depends(get_current_admin)],
) -> list[models.AdminInfo]:
    """Fetch all admin accounts if caller is superuser or system owner."""

    if admin.role not in ("superuser", "owner"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only a superuser or system owner can view admin accounts.",
        )

    records = await DB.fetch(
        """
        SELECT "id", "username", "email", "first_name", "last_name",
               "contact", "created_at",
               "role"
        FROM "admins"
        ORDER BY "created_at" DESC
        """
    )
    return [models.AdminInfo.model_validate(dict(r)) for r in records]


@router.post(
    "/accounts/invite",
    response_model=models.AdminInfo,
    status_code=status.HTTP_201_CREATED,
    summary="Invite a new administrator or superuser",
)
async def invite_admin_account(
    admin: Annotated[models.AdminInfo, Depends(get_current_admin)],
    payload: payloads.AdminCreate,
) -> models.AdminInfo:
    """Invite a new admin or superuser and send invitation email."""
    target_role = (payload.role or "admin").lower()
    if target_role not in ("admin", "superuser", "owner"):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Administrator role must be admin, superuser, or owner.",
        )

    if admin.role == "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only a superuser or system owner can invite new administrators.",
        )

    if admin.role == "superuser" and target_role in ("superuser", "owner"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Superusers can only invite normal administrators. Only a System Owner can invite superusers or owners.",
        )

    # Check for existing admin with same username or email
    existing = await DB.fetchrow(
        'SELECT "username", "email" FROM "admins" WHERE LOWER("username") = LOWER($1) OR LOWER("email") = LOWER($2)',
        payload.username,
        str(payload.email),
    )
    if existing:
        if existing["username"].lower() == payload.username.lower():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Administrator username '@{payload.username}' is already taken.",
            )
        else:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"An administrator account with email '{payload.email}' already exists.",
            )

    generated_password = _generate_random_password()
    generated_pwd_hash = hash_password(generated_password)
    first_name_clean = payload.first_name.strip() if payload.first_name and payload.first_name.strip() else None
    last_name_clean = payload.last_name.strip() if payload.last_name and payload.last_name.strip() else None

    async with DB.transaction() as connection:
        record = await connection.fetchrow(
            """
            INSERT INTO "admins" (
                "username", "password_hash", "email", "first_name",
                "last_name", "role"
            )
            VALUES ($1, $2, $3, $4, $5, $6)
            RETURNING "id", "username", "email", "first_name", "last_name",
                      "contact", "created_at", "role"
            """,
            payload.username,
            generated_pwd_hash,
            str(payload.email),
            first_name_clean,
            last_name_clean,
            target_role,
        )
        if record is None:
            raise RuntimeError("The administrator account was not created.")

    async def _send_email_async():
        try:
            await send_admin_invitation_email(
                payload.email,
                payload.username,
                generated_password,
                target_role,
            )
        except Exception:
            logger.exception("admin credentials email delivery failed")

    asyncio.create_task(_send_email_async())
    return models.AdminInfo.model_validate(dict(record))


def _generate_random_password() -> str:
    prefix = secrets.token_urlsafe(8)
    return f"{prefix}#A1x"


@router.patch(
    "/accounts/{admin_id}/password",
    response_model=responses.BaseResponse,
    summary="Reset password of an administrator account to a new random password",
)
@router.patch(
    "/{admin_id}/password",
    response_model=responses.BaseResponse,
    summary="Reset password of an administrator account to a new random password",
)
@router.put(
    "/{admin_id}/password",
    response_model=responses.BaseResponse,
    summary="Reset password of an administrator account to a new random password",
)
async def update_admin_password(
    admin_id: UUID,
    admin: Annotated[models.AdminInfo, Depends(get_current_admin)],
    request: Request,
    payload: payloads.AdminPasswordChange | None = None,
) -> responses.BaseResponse:
    """Allow superusers and system owners to generate a new random password for an admin and email it."""
    if admin.role not in ("superuser", "owner"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only a superuser or system owner can reset admin passwords.",
        )

    async with DB.transaction() as connection:
        target = await connection.fetchrow(
            """
            SELECT "id", "username", "email", COALESCE("role", 'admin') AS "role"
            FROM "admins"
            WHERE "id" = $1
            FOR UPDATE
            """,
            admin_id,
        )
        if target is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Administrator not found.",
            )

        if admin.role == "superuser" and target["role"] in ("superuser", "owner"):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Superusers cannot reset the password of other superusers or system owners.",
            )

        generated_password = _generate_random_password()
        new_hash = hash_password(generated_password)
        await connection.execute(
            'UPDATE "admins" SET "password_hash" = $1 WHERE "id" = $2',
            new_hash,
            admin_id,
        )
        await revoke_sessions(admin_id, "admin", request.app.state.redis_wrapper)

    async def _send_email_async():
        try:
            await send_admin_password_changed_email(
                target["email"],
                target["username"],
                generated_password,
            )
        except Exception:
            logger.exception("admin password change email failed")

    asyncio.create_task(_send_email_async())
    return responses.BaseResponse(
        message=f"New random password generated and emailed to @{target['username']} ({target['email']})."
    )

    asyncio.create_task(_send_email_async())
    return responses.BaseResponse(message="Administrator password updated and email dispatched.")


@router.patch(
    "/accounts/{admin_id}/role",
    response_model=responses.BaseResponse,
    summary="Change role of an administrator account",
)
async def update_admin_role(
    admin_id: UUID,
    admin: Annotated[models.AdminInfo, Depends(get_current_admin)],
    payload: payloads.AdminRoleUpdate,
) -> responses.BaseResponse:
    """Allow System Owner to update role of an admin."""

    if admin.role != "owner":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only a System Owner can change administrator roles.",
        )

    new_role = payload.role.lower()
    if new_role not in ("admin", "superuser", "owner"):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Administrator role must be admin, superuser, or owner.",
        )

    async with DB.transaction() as connection:
        target = await connection.fetchrow(
            'SELECT "id", "username", "email" FROM "admins" WHERE "id" = $1 FOR UPDATE',
            admin_id,
        )
        if target is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Administrator not found.",
            )

        await connection.execute(
            'UPDATE "admins" SET "role" = $1 WHERE "id" = $2',
            new_role,
            admin_id,
        )

    async def _send_email_async():
        try:
            await send_user_action_email(
                target["email"],
                target["username"],
                "role updated",
                f"Your administrator account role was updated to '{new_role.upper()}'.",
            )
        except Exception:
            logger.exception("admin role update email failed")

    asyncio.create_task(_send_email_async())
    return responses.BaseResponse(message=f"Administrator role updated to {new_role}.")


def _format_pakistan_contact(contact: str) -> str:
    cleaned = contact.strip().replace("-", "").replace(" ", "")
    if cleaned.isdigit() and cleaned.startswith("03") and len(cleaned) == 11:
        return "+92" + cleaned[1:]
    elif cleaned.startswith("+923") and len(cleaned) == 13 and cleaned[1:].isdigit():
        return cleaned
    raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail="Invalid Pakistani contact number. Please use format 03001234567 or +923001234567.",
    )


@router.patch(
    "/profile",
    response_model=responses.BaseResponse,
    summary="Update authenticated administrator's profile info",
)
async def update_admin_profile(
    admin: Annotated[models.AdminInfo, Depends(get_current_admin)],
    payload: payloads.AdminProfileUpdate,
) -> responses.BaseResponse:
    """Update administrator profile fields (username, email, first_name, last_name, contact)."""
    raw_updates = payload.model_dump(exclude_unset=True, exclude_none=True)
    fields_to_update = {}
    for field, new_value in raw_updates.items():
        current_val = getattr(admin, field, None)
        if current_val != new_value:
            fields_to_update[field] = new_value

    if not fields_to_update:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No valid or changed fields were provided for update.",
        )

    new_username = fields_to_update.get("username")
    new_email = fields_to_update.get("email")
    raw_contact = fields_to_update.get("contact")

    if new_username:
        fields_to_update["username"] = new_username.strip()
        username_conflict = await DB.fetchval(
            """
            SELECT 1 FROM "admins" WHERE LOWER("username") = LOWER($1) AND "id" != $2
            UNION ALL
            SELECT 1 FROM "users" WHERE LOWER("username") = LOWER($1)
            """,
            fields_to_update["username"],
            admin.id,
        )
        if username_conflict:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Username '@{fields_to_update['username']}' is already taken.",
            )

    if new_email:
        fields_to_update["email"] = new_email.strip().lower()
        email_conflict = await DB.fetchval(
            """
            SELECT 1 FROM "admins" WHERE LOWER("email") = LOWER($1) AND "id" != $2
            UNION ALL
            SELECT 1 FROM "users" WHERE LOWER("email") = LOWER($1)
            """,
            fields_to_update["email"],
            admin.id,
        )
        if email_conflict:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"An account with email '{fields_to_update['email']}' already exists.",
            )

    if raw_contact:
        formatted_contact = _format_pakistan_contact(raw_contact)
        fields_to_update["contact"] = formatted_contact
        contact_conflict = await DB.fetchval(
            """
            SELECT 1 FROM "admins" WHERE "contact" = $1 AND "id" != $2
            UNION ALL
            SELECT 1 FROM "users" WHERE "contact" = $1
            """,
            formatted_contact,
            admin.id,
        )
        if contact_conflict:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Contact number '{formatted_contact}' is already registered.",
            )

    # Blacklist Checks for new email or new contact
    check_email = fields_to_update.get("email", admin.email).lower()
    check_contact = fields_to_update.get("contact", admin.contact or "")

    is_blacklisted = await DB.fetchval(
        """
        SELECT EXISTS (
            SELECT 1 FROM "blacklist"
            WHERE (LOWER("email") = $1 OR "contact" = $2)
              AND ("duration" IS NULL OR "duration" > CURRENT_TIMESTAMP)
        )
        """,
        check_email,
        check_contact,
    )
    if is_blacklisted:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="The requested email or contact number is blacklisted and cannot be used.",
        )

    set_clause = [
        f'"{field}" = ${i}'
        for i, field in enumerate(fields_to_update.keys(), start=2)
    ]
    query = f'UPDATE "admins" SET {", ".join(set_clause)} WHERE "id" = $1'
    values = [admin.id] + list(fields_to_update.values())

    await DB.execute(query, *values)
    updated_fields_list = list(fields_to_update.keys())

    target_email = new_email if new_email else admin.email
    target_username = new_username if new_username else admin.username
    changes_str = ", ".join(f"{k}: {v}" for k, v in fields_to_update.items())

    async def _send_email_async():
        try:
            await send_user_action_email(
                target_email,
                target_username,
                "admin profile updated",
                f"Your administrator profile details were updated ({changes_str}). If you did not make this change, please contact support.",
            )
        except Exception:
            logger.exception("admin profile update notification email failed")

    asyncio.create_task(_send_email_async())

    return responses.BaseResponse(
        message=f"Successfully updated fields: {', '.join(updated_fields_list)}"
    )


__all__ = ["router"]
