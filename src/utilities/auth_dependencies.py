"""
* Project Name: BONDVAULT PK

* Description: 

* Author: Wolf4605
* Email: mab4605@gmail.com

* Date: 2026-10-23 11:19:18

* Last Modified by: Wolf4605
* Last Modified time: 2026-10-23 20:23:02

* License: MIT
* Copyright© BondVault PK. All rights reserved.
""""""FastAPI dependencies for authenticated users and administrators."""

from typing import Annotated, Literal
from uuid import UUID

import jwt
from fastapi import Depends, HTTPException, Request, Response, status
from fastapi.security import OAuth2PasswordBearer
from pydantic import ValidationError

from ..database import DB
from ..models.admin_model import AdminInfo
from ..models.auth_model import TokenClaims
from ..models.user_model import UserInfo
from ..redis import RedisWrapper
from .auth_tokens import (
    ACCESS_TOKEN_EXPIRES_HEADER,
    ACCESS_TOKEN_HEADER,
    create_access_token,
    decode_access_token,
    token_lifetime,
)

user_oauth2_scheme = OAuth2PasswordBearer(
    tokenUrl="/users/auth/login",
    scheme_name="UserOAuth2",
    description="Sign in with a user account username or email address and password.",
    auto_error=False,
)
admin_oauth2_scheme = OAuth2PasswordBearer(
    tokenUrl="/admins/auth/login",
    scheme_name="AdminOAuth2",
    description="Sign in with an administrator username or email address and password.",
    auto_error=False,
)


def _unauthorized() -> HTTPException:
    """Create a consistent bearer-authentication failure."""
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="A valid bearer access token is required.",
        headers={"WWW-Authenticate": "Bearer"},
    )


def _token_claims(
    token: str | None,
) -> TokenClaims:
    """Decode OAuth2 bearer credentials, translating invalid tokens to 401."""
    if token is None:
        raise _unauthorized()
    try:
        return decode_access_token(token)
    except (jwt.InvalidTokenError, ValidationError) as error:
        raise _unauthorized() from error


def _refresh_response(
    response: Response,
    subject: UUID,
    role: Literal["user", "admin"],
    session_id: UUID,
) -> None:
    """Attach a freshly expiring token to each authenticated response."""
    response.headers[ACCESS_TOKEN_HEADER] = create_access_token(
        subject,
        role,
        session_id,
    )
    response.headers[ACCESS_TOKEN_EXPIRES_HEADER] = str(
        int(token_lifetime().total_seconds())
    )


def clear_access_token_headers(response: Response) -> None:
    """Prevent a revoked session's refreshed token from being returned."""
    if ACCESS_TOKEN_HEADER in response.headers:
        del response.headers[ACCESS_TOKEN_HEADER]
    if ACCESS_TOKEN_EXPIRES_HEADER in response.headers:
        del response.headers[ACCESS_TOKEN_EXPIRES_HEADER]


async def revoke_sessions(
    subject: UUID,
    role: Literal["user", "admin"],
    redis: RedisWrapper,
    session_id: UUID | None = None,
) -> None:
    """Revoke one session or every session belonging to an account."""
    if session_id is not None:
        await redis.revoke_session(subject, role, session_id)
        return
    await redis.revoke_account_sessions(subject, role)


async def _refresh_active_session(
    claims: TokenClaims,
    response: Response,
    redis: RedisWrapper,
) -> None:
    """Extend an active session and return a replacement access token."""
    lifetime_seconds = int(token_lifetime().total_seconds())
    active = await redis.refresh_session(
        claims.sub,
        claims.role,
        claims.sid,
        lifetime_seconds,
    )
    if not active:
        raise _unauthorized()

    _refresh_response(response, claims.sub, claims.role, claims.sid)


async def get_current_user(
    credentials: Annotated[
        str | None,
        Depends(user_oauth2_scheme),
    ],
    response: Response,
    request: Request,
) -> UserInfo:
    """Resolve and refresh the authenticated user's payload."""
    claims = _token_claims(credentials)
    if claims.role != "user":
        raise _unauthorized()

    record = await DB.fetchrow(
        """
        SELECT "id", "username", "email", "first_name", "last_name",
               "contact", "created_at", "is_verified", "verified_by", "last_login"
        FROM "users"
        WHERE "id" = $1
        """,
        claims.sub,
    )
    if record is None:
        raise _unauthorized()
    payload = UserInfo.model_validate(dict(record))

    request.state.session_id = claims.sid
    await _refresh_active_session(
        claims,
        response,
        request.app.state.redis_wrapper,
    )
    return payload


async def get_current_admin(
    credentials: Annotated[
        str | None,
        Depends(admin_oauth2_scheme),
    ],
    response: Response,
    request: Request,
) -> AdminInfo:
    """Resolve and refresh the authenticated administrator payload."""
    claims = _token_claims(credentials)
    if claims.role != "admin":
        raise _unauthorized()

    record = await DB.fetchrow(
        """
        SELECT "id", "username", "email", "first_name", "last_name",
               "contact", "created_at", "is_superuser"
        FROM "admins"
        WHERE "id" = $1
        """,
        claims.sub,
    )
    if record is None:
        raise _unauthorized()
    payload = AdminInfo.model_validate(dict(record))

    request.state.admin_payload = payload
    request.state.session_id = claims.sid
    await _refresh_active_session(
        claims,
        response,
        request.app.state.redis_wrapper,
    )
    return payload


__all__ = [
    "clear_access_token_headers",
    "get_current_admin",
    "get_current_user",
    "revoke_sessions",
]
