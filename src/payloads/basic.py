"""
* Project Name: BONDVAULT PK

* Description: Contains the base Payloads on which to build other payloads.

* Author: Wolf4605
* Email: mab4605@gmail.com

* Date: 2026-10-23 13:25:53

* Last Modified by: Wolf4605
* Last Modified time: 2026-10-23 13:25:54

* License: MIT
* Copyright© BondVault PK. All rights reserved.
"""

from datetime import UTC, date, datetime
from typing import Literal

from pydantic import (
    AwareDatetime,
    BaseModel,
    ConfigDict,
    EmailStr,
    Field,
    SecretStr,
    field_validator,
)

from ..configs import PrizeBondDenominations
from ..utilities.auth import hash_password


class LoginPayload(BaseModel):
    """Credentials submitted to either login endpoint."""

    username: str = Field(min_length=1, max_length=254, description="The account username.")
    password: SecretStr = Field(min_length=1, description="The account password.")


class EmailVerificationRequest(BaseModel):
    """Request an email verification code."""

    email: EmailStr


class EmailVerificationCheck(BaseModel):
    """Submit an emailed verification code."""

    email: EmailStr
    code: str = Field(pattern=r"^[0-9]{6}$")


class UserPasswordRecoveryRequest(BaseModel):
    """Request a password recovery code."""

    email: EmailStr


class UserPasswordRecoveryComplete(BaseModel):
    """Complete password recovery with an emailed code."""

    email: EmailStr
    code: str = Field(pattern=r"^[0-9]{6}$")
    new_password: str = Field(min_length=12, max_length=256)


class UpcomingDrawCreate(BaseModel):
    """Create one upcoming draw schedule entry."""

    denomination: PrizeBondDenominations
    draw_date: date


class BondAddPayload(BaseModel):
    """Payload to add/delete bond(s) to a user."""
    bonds: str | list[str] = Field(default=..., description="The prize bond number or a list of prize bond_numbers", examples=["000001", "[\"000001\", \"000002\", \"000003\"]"])
    denomination: PrizeBondDenominations = Field(default=..., description= "The denomination of the prize bond.")

    @field_validator("bonds")
    def convert_str_to_list(cls, x:str) -> list[str]:
        new_list:list[str]|str = x
        if isinstance(x,str):
            new_list = [x]

        for z in new_list:
            if not z.isdigit():
                raise ValueError("The list should only contian digits, no alphabets are allowed.")

        return new_list


class AddBondsByRange(BaseModel):
    """Payload to add/delete bonds for a user by a given range."""
    denomination: PrizeBondDenominations = Field(default=..., description= "The denomination of the prize bond.")
    start_num: str = Field(default = ..., description="First prize-bond number, inclusive; 1 to 999999.")
    end_num: str = Field(default = ..., description="Last prize-bond number, inclusive; 1 to 999999.")
class ChangePassword(BaseModel):
    """Payload for changing a users password."""
    old_password: str = Field(default=..., description="The current password of the user.")
    new_password: str = Field(default=..., description="The new user password that is to be set. **Should not be same as the current password.")


class AdminRegister(BaseModel):
    """A model to be used when registering an `administrator`."""
    username: str = Field(
            default=...,
            description="`UNIQUE` Identifier of the administrator.",
            examples=["Wolf_4605", "proximizer", "user123"]
            )
    """`UNIQUE` Identifier of the administrator."""
    email: EmailStr = Field(
        default=...,
        description="Email Address of the administrator.",
        examples=["user@example.com", "wolf@example.com", "user@gmail.com"]
        )
    """Email Address of the administrator."""
    password_hash: str = Field(
        default=...,
        description="Password Hash of the administrator via Argon2. A normal password can be used and the backend will automatically hash it by using argon2.",
        examples=["YOUR_PASSword", "ChangeMe123!"]
        )
    """Password Hash of the user via Argon2. A normal password can be used and the backend will automatically hash it by using argon2."""
    first_name: str = Field(
        default=...,
        description="First Name of the administrator.",
        examples=["Awais", "Alice", "Bob"]
        )
    "First Name of the administrator."
    last_name: str = Field(
        default=...,
        description="Contact Number of the administrator.",
        examples=["Bilal", "Carter", "Griffin"]
        )
    "Contact Number of the administrator."
    contact: str = Field(
        default=...,
        description="Contact number of the administrator.",
        examples=["03121234567", "+923001122344"]
        )
    "Contact number of the administrator."

    is_superuser: bool

    @field_validator("password_hash")
    @classmethod
    def __hash_password(cls, x:str):
        """Hash the user password."""
        return hash_password(x)

    @field_validator("contact")
    @classmethod
    def format_contact(cls, x:str):
        """Formatting the contact to start"""
        if x.isdigit() and x.startswith("03") and len(x)==11:
            return x.replace("0","+92",1)
        elif (x.startswith("+92") and x.count('+')==1 
              and 
              x.strip("+").isdigit() and len(x)==13):
            return x
        else:
            raise ValueError("Invalid Contact Number. Please use a valid Pakistani Mobile Operator Number.")

class AdminCreate(BaseModel):
    """Details for creating an administrator that will activate their account."""

    username: str = Field(min_length=1, max_length=50)
    email: EmailStr
    first_name: str | None = Field(default=None, max_length=100)
    last_name: str | None = Field(default=None, max_length=100)


class AdminActivate(BaseModel):
    """One-time invitation and new password for administrator account activation."""

    email: EmailStr
    token: str = Field(min_length=32, max_length=128)
    new_password: SecretStr = Field(min_length=12, max_length=256)


class UserBlacklistRequest(BaseModel):
    """Blacklist a user permanently or until a future timestamp."""

    duration_until: AwareDatetime | None = Field(
        default=None,
        description="UTC timestamp when the blacklist expires; omit for permanent.",
    )
    reason: str | None = Field(
        default=None,
        description="Optional reason for blacklisting the user.",
    )

    @field_validator("duration_until")
    @classmethod
    def require_future_expiration(
        cls,
        value: datetime | None,
    ) -> datetime | None:
        if value is not None and value <= datetime.now(UTC):
            raise ValueError("duration_until must be a future timestamp.")
        return value


class UserInfoUpdate(BaseModel):
    """Fields that can be updated by the user."""
    username: str|None = Field(default=None, description="The user's unique username.")
    email: str|None = Field(default=None, description="The user's email address.")
    first_name: str | None = Field(default=None, description="The user's first name, if provided.")
    last_name: str | None = Field(default=None, description="The user's last name, if provided.")
    contact: str | None = Field(default=None, description="The user's contact number, if provided.")
    city: str | None = Field(
        default=None,
        min_length=1,
        max_length=100,
        description="The user's city.",
    )
    address: str | None = Field(
        default=None,
        min_length=1,
        description="The user's street or postal address.",
    )

    @field_validator("city", "address", mode="before")
    @classmethod
    def normalize_profile_text(cls, value: object) -> object:
        """Trim surrounding whitespace from profile location updates."""
        return value.strip() if isinstance(value, str) else value

    @field_validator("contact")
    @classmethod
    def format_contact(cls, x:str):
        """Formatting the contact to start"""
        if x.isdigit() and x.startswith("03") and len(x)==11:
            return x.replace("0","+92",1)
        elif (x.startswith("+92") and x.count('+')==1 
                and 
                x.strip("+").isdigit() and len(x)==13):
            return x
        else:
            raise ValueError("Invalid Contact Number. Please use a valid Pakistani Mobile Operator Number.")


class MarketListingCreate(BaseModel):
    """Fields required to publish a marketplace listing."""

    title: str = Field(min_length=1, max_length=150)
    description: str | None = None
    price: int = Field(ge=0)
    category: Literal["buy", "sell"]

    @field_validator("title", mode="before")
    @classmethod
    def normalize_title(cls, value: object) -> object:
        """Trim a listing title before validating it."""
        return value.strip() if isinstance(value, str) else value


class MarketListingUpdate(BaseModel):
    """Fields a listing owner may update."""

    model_config = ConfigDict(extra="forbid")

    title: str | None = Field(default=None, min_length=1, max_length=150)
    description: str | None = None
    price: int | None = Field(default=None, ge=0)
    category: Literal["buy", "sell"] | None = None

    @field_validator("title", mode="before")
    @classmethod
    def normalize_title(cls, value: object) -> object:
        """Trim an updated title before validating it."""
        return value.strip() if isinstance(value, str) else value

    @field_validator("title", "price", "category")
    @classmethod
    def reject_null_required_fields(cls, value: object) -> object:
        """Keep required listing fields from being cleared with null."""
        if value is None:
            raise ValueError("This field cannot be null.")
        return value


class MarketListingRemovalRequest(BaseModel):
    """Reason an administrator is removing a marketplace listing."""

    model_config = ConfigDict(extra="forbid")

    reason: str = Field(min_length=3, max_length=1000)

    @field_validator("reason", mode="before")
    @classmethod
    def normalize_reason(cls, value: object) -> object:
        """Trim a removal reason before validating it."""
        return value.strip() if isinstance(value, str) else value
