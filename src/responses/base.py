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

from typing import Literal
from uuid import UUID

from fastapi import status
from pydantic import BaseModel, Field

from .. import models


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