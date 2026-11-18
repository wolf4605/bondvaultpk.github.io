"""JWT token claims and authentication payload models."""

from typing import Literal
from uuid import UUID

from pydantic import BaseModel


class TokenClaims(BaseModel):
    """Validated claims required for an API access token."""

    sub: UUID
    role: Literal["user", "admin"]
    sid: UUID
    iat: int
    exp: int
    jti: UUID


__all__ = [
    "TokenClaims",
]
