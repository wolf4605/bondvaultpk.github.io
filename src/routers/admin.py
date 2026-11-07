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

import logging
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Request, status
from redis.exceptions import RedisError
from starlette.exceptions import HTTPException

from .. import models, payloads, responses
from ..database import DB
from ..services.email_service import (
    EmailDeliveryError,
    send_market_listing_removed_email,
    send_user_action_email,
)
from ..utilities.auth_dependencies import get_current_admin, revoke_sessions

router = APIRouter(prefix="/admins",
                   tags=["Administrators"])
logger = logging.getLogger("application.audit")


async def _notify_user_action(
    email: str,
    username: str,
    action: str,
    details: str,
) -> None:
    """Make notification failures explicit after a committed account action."""
    try:
        await send_user_action_email(email, username, action, details)
    except EmailDeliveryError as error:
        logger.exception(
            "user account action completed but notification email failed",
            extra={"event": "user.notification.email_failed", "action": action},
        )
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=(
                f"The account was {action}, but the notification email could not "
                "be sent. The account action has already taken effect."
            ),
        ) from error


async def _revoke_sessions_and_notify_user(
    user_id: UUID,
    email: str,
    username: str,
    action: str,
    details: str,
    request: Request,
) -> None:
    """Attempt session revocation and email independently after the DB action."""
    failures: list[str] = []
    try:
        await revoke_sessions(
            user_id,
            "user",
            request.app.state.redis_wrapper,
        )
    except (ConnectionError, RedisError, OSError, TimeoutError):
        logger.exception(
            "user account action completed but session revocation failed",
            extra={"event": "user.session.revocation_failed", "action": action},
        )
        failures.append("active sessions could not be revoked")

    try:
        await send_user_action_email(email, username, action, details)
    except RuntimeError:
        logger.exception(
            "user account action completed but notification email failed",
            extra={"event": "user.notification.email_failed", "action": action},
        )
        failures.append("the notification email could not be sent")

    if failures:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=(
                f"The account was {action}, but "
                f"{' and '.join(failures)}. The account action has already taken effect."
            ),
        )


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


@router.get(
    "/users/blacklist",
    response_model=responses.BlacklistedUsersResponse,
    summary="Fetch active blacklisted users",
)
async def fetch_blacklisted_users(
    admin: Annotated[models.AdminInfo, Depends(get_current_admin)],
) -> responses.BlacklistedUsersResponse:
    """Return active blacklist entries and matching accounts where available."""
    records = await DB.fetch(
        """
        SELECT blacklist."id", users."id" AS "user_id", users."username",
               blacklist."email", blacklist."contact", blacklist."duration",
               blacklist."reason", blacklist."created_at"
        FROM "blacklist"
        LEFT JOIN "users"
          ON users."email" = blacklist."email"
          OR users."contact" = blacklist."contact"
        WHERE blacklist."duration" IS NULL
           OR blacklist."duration" > CURRENT_TIMESTAMP
        ORDER BY blacklist."created_at" DESC, blacklist."id"
        """
    )
    blacklisted_users = [
        responses.BlacklistedUserInfo.model_validate(dict(record))
        for record in records
    ]
    return responses.BlacklistedUsersResponse(
        message=f"Found {len(blacklisted_users)} active blacklist entries.",
        blacklisted_users=blacklisted_users,
        total=len(blacklisted_users),
    )


@router.get(
    "/market/listings",
    response_model=responses.AdminMarketListingsResponse,
    summary="Fetch all marketplace listings",
)
async def fetch_market_listings(
    admin: Annotated[models.AdminInfo, Depends(get_current_admin)],
) -> responses.AdminMarketListingsResponse:
    """Return all marketplace listings with their owners' contact details."""
    records = await DB.fetch(
        """
        SELECT market."id", market."posted_by", market."title",
               market."description", market."price", market."category",
               market."created_at", users."username" AS "owner_username",
               users."email" AS "owner_email"
        FROM "market"
        JOIN "users" ON users."id" = market."posted_by"
        ORDER BY market."created_at" DESC, market."id"
        """
    )
    listings = [
        responses.AdminMarketListingInfo.model_validate(dict(record))
        for record in records
    ]
    return responses.AdminMarketListingsResponse(
        message=f"Found {len(listings)} marketplace listings.",
        listings=listings,
        total=len(listings),
    )


@router.delete(
    "/market/listings/{listing_id}",
    response_model=responses.BaseResponse,
    summary="Delete a marketplace listing",
)
async def delete_market_listing(
    listing_id: UUID,
    admin: Annotated[models.AdminInfo, Depends(get_current_admin)],
) -> responses.BaseResponse:
    """Delete any marketplace listing and email its owner."""
    async with DB.transaction() as connection:
        listing = await connection.fetchrow(
            """
            SELECT market."id", market."title", users."username", users."email"
            FROM "market"
            JOIN "users" ON users."id" = market."posted_by"
            WHERE market."id" = $1
            FOR UPDATE OF market, users
            """,
            listing_id,
        )
        if listing is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Marketplace listing not found.",
            )

        deleted_id = await connection.fetchval(
            """
            DELETE FROM "market"
            WHERE "id" = $1
            RETURNING "id"
            """,
            listing_id,
        )
        if deleted_id is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Marketplace listing not found.",
            )

    logger.warning(
        "marketplace listing deleted by administrator",
        extra={
            "event": "market.listing.admin_deleted",
            "subject_id": str(listing_id),
            "actor_id": str(admin.id),
        },
    )
    try:
        await send_market_listing_removed_email(
            listing["email"],
            listing["username"],
            listing["title"],
        )
    except EmailDeliveryError as error:
        logger.exception(
            "marketplace listing deleted but notification email failed",
            extra={"event": "market.listing.notification.email_failed"},
        )
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=(
                "The listing was deleted, but the notification email could not "
                "be sent. The listing deletion has already taken effect."
            ),
        ) from error

    return responses.BaseResponse(
        message="Marketplace listing deleted and owner notified."
    )


@router.post(
    "/users/{user_id}/approve",
    response_model=responses.BaseResponse,
    summary="Approve a user account",
)
async def approve_user(
    user_id: UUID,
    admin: Annotated[models.AdminInfo, Depends(get_current_admin)],
) -> responses.BaseResponse:
    """Approve a pending user and email the account owner."""
    async with DB.transaction() as connection:
        user = await connection.fetchrow(
            """
            SELECT "id", "username", "email", "contact", "is_verified"
            FROM "users"
            WHERE "id" = $1
            FOR UPDATE
            """,
            user_id,
        )
        if user is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found.",
            )
        if user["is_verified"]:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="User account is already approved.",
            )

        is_blacklisted = await connection.fetchval(
            """
            SELECT EXISTS(
                SELECT 1
                FROM "blacklist"
                WHERE ("email" = $1 OR "contact" = $2)
                  AND ("duration" IS NULL OR "duration" > CURRENT_TIMESTAMP)
            )
            """,
            user["email"],
            user["contact"],
        )
        if is_blacklisted:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="A blacklisted user cannot be approved.",
            )

        updated_user = await connection.fetchrow(
            """
            UPDATE "users"
            SET "is_verified" = TRUE, "verified_by" = $2
            WHERE "id" = $1
            RETURNING "username", "email"
            """,
            user_id,
            admin.id,
        )
        if updated_user is None:
            raise RuntimeError("The user approval update returned no user.")

    logger.info(
        "user account approved",
        extra={
            "event": "user.approved",
            "subject_id": str(user_id),
            "actor_id": str(admin.id),
        },
    )
    await _notify_user_action(
        updated_user["email"],
        updated_user["username"],
        "approved",
        "You can now sign in to your account.",
    )
    return responses.BaseResponse(message="User approved and notification sent.")


@router.post(
    "/users/{user_id}/blacklist",
    response_model=responses.BaseResponse,
    summary="Blacklist a user account",
)
async def blacklist_user(
    user_id: UUID,
    payload: payloads.UserBlacklistRequest,
    admin: Annotated[models.AdminInfo, Depends(get_current_admin)],
    request: Request,
) -> responses.BaseResponse:
    """Blacklist a user permanently or until the supplied expiration time."""
    async with DB.transaction() as connection:
        user = await connection.fetchrow(
            """
            SELECT "id", "username", "email", "contact"
            FROM "users"
            WHERE "id" = $1
            FOR UPDATE
            """,
            user_id,
        )
        if user is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found.",
            )

        already_blacklisted = await connection.fetchval(
            """
            SELECT EXISTS(
                SELECT 1
                FROM "blacklist"
                WHERE ("email" = $1 OR "contact" = $2)
                  AND ("duration" IS NULL OR "duration" > CURRENT_TIMESTAMP)
            )
            """,
            user["email"],
            user["contact"],
        )
        if already_blacklisted:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="User is already actively blacklisted.",
            )

        blacklist_record = await connection.fetchrow(
            """
            INSERT INTO "blacklist" ("email", "contact", "duration", "reason")
            VALUES ($1, $2, $3, $4)
            RETURNING "id"
            """,
            user["email"],
            user["contact"],
            payload.duration_until,
            payload.reason,
        )
        if blacklist_record is None:
            raise RuntimeError("The user blacklist entry was not created.")

    if payload.duration_until is None:
        details = (
            "Your account has been permanently blacklisted and removed. "
            "You can no longer sign in."
        )
    else:
        details = (
            "Your account cannot be used until "
            f"{payload.duration_until.isoformat()}."
        )
    logger.warning(
        "user account blacklisted",
        extra={
            "event": "user.blacklisted",
            "subject_id": str(user_id),
            "actor_id": str(admin.id),
            "permanent": payload.duration_until is None,
        },
    )
    await _revoke_sessions_and_notify_user(
        user_id,
        user["email"],
        user["username"],
        "blacklisted",
        details,
        request,
    )
    return responses.BaseResponse(message="User blacklisted and notification sent.")


@router.delete(
    "/users/{user_id}/blacklist",
    response_model=responses.BaseResponse,
    summary="Remove a user's blacklist",
)
async def unblacklist_user(
    user_id: UUID,
    admin: Annotated[models.AdminInfo, Depends(get_current_admin)],
    request: Request,
) -> responses.BaseResponse:
    """Remove an active temporary blacklist and email the account owner."""
    async with DB.transaction() as connection:
        user = await connection.fetchrow(
            """
            SELECT "id", "username", "email", "contact"
            FROM "users"
            WHERE "id" = $1
            FOR UPDATE
            """,
            user_id,
        )
        if user is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found.",
            )

        blacklist_records = await connection.fetch(
            """
            DELETE FROM "blacklist"
            WHERE ("email" = $1 OR "contact" = $2)
              AND ("duration" IS NULL OR "duration" > CURRENT_TIMESTAMP)
            RETURNING "id"
            """,
            user["email"],
            user["contact"],
        )
        if not blacklist_records:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="User does not have an active blacklist.",
            )

    logger.info(
        "user account removed from blacklist",
        extra={
            "event": "user.unblacklisted",
            "subject_id": str(user_id),
            "actor_id": str(admin.id),
        },
    )
    await _revoke_sessions_and_notify_user(
        user_id,
        user["email"],
        user["username"],
        "unblacklisted",
        "Your account can now be used again. Sign in to access your account.",
        request,
    )
    return responses.BaseResponse(
        message="User unblacklisted and notification sent."
    )


@router.delete(
    "/users/{user_id}",
    response_model=responses.BaseResponse,
    summary="Delete a user account",
)
async def delete_user(
    user_id: UUID,
    admin: Annotated[models.AdminInfo, Depends(get_current_admin)],
    request: Request,
) -> responses.BaseResponse:
    """Delete a user, revoke their sessions, and email the account owner."""
    async with DB.transaction() as connection:
        user = await connection.fetchrow(
            """
            DELETE FROM "users"
            WHERE "id" = $1
            RETURNING "username", "email"
            """,
            user_id,
        )
        if user is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found.",
            )

    logger.warning(
        "user account deleted",
        extra={
            "event": "user.deleted",
            "subject_id": str(user_id),
            "actor_id": str(admin.id),
        },
    )
    await _revoke_sessions_and_notify_user(
        user_id,
        user["email"],
        user["username"],
        "deleted",
        "Your account and associated account data have been removed.",
        request,
    )
    return responses.BaseResponse(message="User deleted and notification sent.")
