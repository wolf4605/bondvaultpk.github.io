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

from pydantic import BaseModel, EmailStr, Field, SecretStr, field_validator

from ..configs import PrizeBondDenominations
from ..utilities.auth import hash_password


class LoginPayload(BaseModel):
    """Credentials submitted to either login endpoint."""

    username: str = Field(min_length=1, max_length=254, description="The account username.")
    password: SecretStr = Field(min_length=1, description="The account password.")

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

class UserInfoUpdate(BaseModel):
    """Fields that can be updated by the user."""
    username: str|None = Field(default=None, description="The user's unique username.")
    email: str|None = Field(default=None, description="The user's email address.")
    first_name: str | None = Field(default=None, description="The user's first name, if provided.")
    last_name: str | None = Field(default=None, description="The user's last name, if provided.")
    contact: str | None = Field(default=None, description="The user's contact number, if provided.")

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


 