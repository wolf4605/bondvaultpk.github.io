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

import asyncio
import secrets

from fastapi import APIRouter, Request, Response, status
from redis.exceptions import RedisError
from starlette.exceptions import HTTPException

from .. import payloads, responses
from ..database import DB
from ..services.email_service import (
    EmailDeliveryError,
    send_verification_code_email,
)

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
    path="/health",
    response_model=responses.HealthResponse,
    responses={
        status.HTTP_503_SERVICE_UNAVAILABLE: {
            "model": responses.HealthResponse,
            "description": "Backend or a required dependency is unavailable.",
        }
    },
    summary="Get backend and dependency health",
)
@router.get(
    path="",
    response_model=responses.HealthResponse,
    include_in_schema=False,
)
async def get_health(
    request: Request,
    response: Response,
) -> responses.HealthResponse:
    """Report backend, PostgreSQL, and Redis availability."""
    redis_wrapper = getattr(request.app.state, "redis_wrapper", None)
    if redis_wrapper is None:
        database_is_healthy = await DB.check_health()
        redis_is_healthy = False
    else:
        database_is_healthy, redis_is_healthy = await asyncio.gather(
            DB.check_health(),
            redis_wrapper.check_health(),
        )

    is_healthy = database_is_healthy and redis_is_healthy
    if not is_healthy:
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE

    return responses.HealthResponse(
        status="healthy" if is_healthy else "unhealthy",
        backend=responses.HealthComponentStatus(status="up"),
        database=responses.HealthComponentStatus(
            status="up" if database_is_healthy else "down"
        ),
        redis=responses.HealthComponentStatus(
            status="up" if redis_is_healthy else "down"
        ),
    )


@router.post(
    path="/verification-code",
    response_model=responses.BaseResponse,
    status_code=status.HTTP_202_ACCEPTED,
    summary="Send an email verification code",
)
async def send_email_verification_code(
    payload: payloads.EmailVerificationRequest,
    request: Request,
) -> responses.BaseResponse:
    """Email a six-digit code; never include the code in the API response."""
    redis_wrapper = getattr(request.app.state, "redis_wrapper", None)
    if redis_wrapper is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Verification service is unavailable.",
        )

    client_ip = request.client.host if request.client is not None else "unknown"
    code = f"{secrets.randbelow(1_000_000):06d}"
    try:
        result = await redis_wrapper.create_email_verification_code(
            str(payload.email),
            code,
            client_ip,
        )
    except (ConnectionError, RedisError, OSError, TimeoutError) as error:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Verification service is unavailable.",
        ) from error
    if result == 1:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="A verification code was recently sent to this email address.",
            headers={"Retry-After": str(redis_wrapper.EMAIL_VERIFICATION_RESEND_SECONDS)},
        )
    if result == 2:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many verification requests. Please try again later.",
            headers={"Retry-After": str(redis_wrapper.EMAIL_VERIFICATION_IP_WINDOW_SECONDS)},
        )
    if result != 0:
        raise RuntimeError("The verification code could not be stored.")

    try:
        await send_verification_code_email(payload.email, code)
    except EmailDeliveryError:
        await redis_wrapper.discard_email_verification_code(str(payload.email))
        raise

    return responses.BaseResponse(
        status_code=status.HTTP_202_ACCEPTED,
        message="Verification code sent. It expires in 10 minutes.",
    )


@router.post(
    path="/verification-code/verify",
    response_model=responses.EmailVerificationResponse,
    summary="Verify an email address",
)
async def verify_email_code(
    payload: payloads.EmailVerificationCheck,
    request: Request,
) -> responses.EmailVerificationResponse:
    """Verify an email address using its active, single-use code."""
    redis_wrapper = getattr(request.app.state, "redis_wrapper", None)
    if redis_wrapper is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Verification service is unavailable.",
        )

    try:
        verified = await redis_wrapper.verify_email_verification_code(
            str(payload.email),
            payload.code,
        )
    except (ConnectionError, RedisError, OSError, TimeoutError) as error:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Verification service is unavailable.",
        ) from error
    if not verified:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="The verification code is invalid or expired.",
        )
    return responses.EmailVerificationResponse(
        verified=True,
        message="Email address verified.",
    )
