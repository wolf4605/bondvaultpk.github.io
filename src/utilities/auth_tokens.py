"""Create and validate short-lived JWT access tokens."""

from datetime import UTC, datetime, timedelta
from typing import Literal
from uuid import UUID, uuid4

import jwt

from ..configs import ACCESS_TOKEN_IDLE_TIMEOUT_MINUTES, JWT_ALGORITHM
from ..configs.auth_configs import get_jwt_secret
from ..models.auth_model import TokenClaims

ACCESS_TOKEN_HEADER = "X-Access-Token"
ACCESS_TOKEN_EXPIRES_HEADER = "X-Access-Token-Expires-In"


def validate_jwt_config() -> None:
    """Fail startup early when the signing key is missing or too weak."""
    get_jwt_secret()
    token_lifetime()


def token_lifetime() -> timedelta:
    """Return the configured idle lifetime for access tokens."""
    if ACCESS_TOKEN_IDLE_TIMEOUT_MINUTES < 1:
        raise RuntimeError("ACCESS_TOKEN_IDLE_TIMEOUT_MINUTES must be greater than zero.")
    return timedelta(minutes=ACCESS_TOKEN_IDLE_TIMEOUT_MINUTES)


def create_access_token(
    subject: UUID,
    role: Literal["user", "admin"],
    session_id: UUID,
) -> str:
    """Create a signed token whose expiry is based on the current activity."""
    issued_at = datetime.now(UTC)
    expires_at = issued_at + token_lifetime()
    return jwt.encode(
        {
            "sub": str(subject),
            "role": role,
            "sid": str(session_id),
            "iat": int(issued_at.timestamp()),
            "exp": int(expires_at.timestamp()),
            "jti": str(uuid4()),
        },
        get_jwt_secret(),
        algorithm=JWT_ALGORITHM,
    )


def decode_access_token(token: str) -> TokenClaims:
    """Decode a token and validate its required claims and signature."""
    claims = jwt.decode(
        token,
        get_jwt_secret(),
        algorithms=[JWT_ALGORITHM],
        options={"require": ["sub", "role", "sid", "iat", "exp", "jti"]},
    )
    return TokenClaims.model_validate(claims)


__all__ = [
    "ACCESS_TOKEN_EXPIRES_HEADER",
    "ACCESS_TOKEN_HEADER",
    "create_access_token",
    "decode_access_token",
    "token_lifetime",
    "validate_jwt_config",
]
