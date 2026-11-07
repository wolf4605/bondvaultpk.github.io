"""
* Project Name: BONDVAULT PK

* Description: 

* Author: Wolf4605
* Email: mab4605@gmail.com

* Date: 2026-10-23 19:26:49

* Last Modified by: Wolf4605
* Last Modified time: 2026-10-23 19:26:51

* License: MIT
* Copyright© BondVault PK. All rights reserved.
"""

from datetime import date, datetime
from typing import Literal
from uuid import UUID

from fastapi import status
from pydantic import BaseModel, Field

from .. import models
from ..configs import PrizeBondDenominations


class BaseResponse(BaseModel):
    """The Base Response for all the responses."""
    status_code: int = Field(default=status.HTTP_200_OK, description= "The status code for the request.")
    message: str|None = Field(default = None, description = "The message to attach along with the response.")

class AdminRegister(BaseResponse):
    """The Response to be sent when registering a new_user."""
class UserResponseBase(BaseResponse):
    """The Base response for the requests that are made by authenticated users."""
    id:UUID
    """The Unique identifier of the user."""
    username : str
    """Username of the user."""

class UserBondlistGet(UserResponseBase):
    """The response model to be send when a user asks for his bondlist(s)."""
    bondlists: models.BondListsExtended|models.BondListsBasic = Field(default = models.BondListsBasic(), description = "A list containing the users bondlists.")
class UserInfoResponse(BaseResponse):
    """Response for sending the minimal user info."""
    user_info: models.UserInfo
    """The user information feched from the database."""


class UserLoginResponse(BaseModel):
    """Access token and public user information returned after login."""

    access_token: str
    token_type: Literal["bearer"] = "bearer"
    expires_in: int = Field(ge=1, description="Token lifetime in seconds.")
    payload: models.UserInfo

class AdminLoginResponse(BaseModel):
    """Access token and public administrator information returned after login."""

    access_token: str
    token_type: Literal["bearer"] = "bearer"
    expires_in: int = Field(ge=1, description="Token lifetime in seconds.")
    payload: models.AdminInfo

class AllUsersResponse(BaseResponse):
    users: list[models.UserInfo] = []


class BlacklistedUserInfo(BaseModel):
    """An active blacklist entry and its matching account, if it still exists."""

    id: UUID
    user_id: UUID | None
    username: str | None
    email: str
    contact: str
    duration: datetime | None
    reason: str | None
    created_at: datetime


class BlacklistedUsersResponse(BaseResponse):
    """Active blacklist entries returned to administrators."""

    blacklisted_users: list[BlacklistedUserInfo]
    total: int = Field(ge=0)


class ActiveUsersResponse(BaseModel):
    """Registered and currently online user counts."""

    total_registered_users: int = Field(ge=0)
    currently_online_users: int = Field(ge=0)


class HealthComponentStatus(BaseModel):
    """Health state for one backend dependency."""

    status: Literal["up", "down"]


class HealthResponse(BaseModel):
    """Overall backend and dependency health."""

    status: Literal["healthy", "unhealthy"]
    backend: HealthComponentStatus
    database: HealthComponentStatus
    redis: HealthComponentStatus


class UpcomingDrawInfo(BaseModel):
    """An upcoming prize-bond draw schedule entry."""

    draw_date: date
    denomination: PrizeBondDenominations
    created_at: datetime


class EmailVerificationResponse(BaseResponse):
    """Result of an email verification attempt."""

    verified: bool


class PrizeBondDrawMatch(BaseModel):
    """A winning bond and the draw in which it was selected."""

    bond_number: str
    denomination: PrizeBondDenominations
    prize_position: Literal[1, 2, 3]
    prize_name: Literal["1st Prize", "2nd Prize", "3rd Prize"]
    prize_amount: int
    draw_date: date


class PrizeBondSearchResponse(BaseModel):
    """All matching prize-bond draw results."""

    results: list[PrizeBondDrawMatch]
    total: int = Field(ge=0, description="Total number of matching results.")


class MarketListingInfo(BaseModel):
    """Public listing details returned after a user's marketplace action."""

    id: UUID
    posted_by: UUID
    title: str
    description: str | None
    price: int
    category: Literal["buy", "sell"]
    created_at: datetime


class AdminMarketListingInfo(MarketListingInfo):
    """Marketplace listing and owner contact details for administrators."""

    owner_username: str
    owner_email: str


class AdminMarketListingsResponse(BaseResponse):
    """All marketplace listings returned to administrators."""

    listings: list[AdminMarketListingInfo]
    total: int = Field(ge=0)