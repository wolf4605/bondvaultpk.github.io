"""
* Project Name: BONDVAULT PK

* Description: Request and response models for user and administrator authentication.

* Author: Wolf4605
* Email: mab4605@gmail.com

* Date: 2026-10-23 11:19:18

* Last Modified by: Wolf4605
* Last Modified time: 2026-10-23 11:55:00

* License: MIT
* Copyright© BondVault PK. All rights reserved.
"""

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
