"""
* Project Name: BONDVAULT PK

* Description: 

* Author: Wolf4605
* Email: mab4605@gmail.com

* Date: 2026-10-30 07:30:48

* Last Modified by: Wolf4605
* Last Modified time: 2026-10-30 07:31:11

* License: MIT
* Copyright© BondVault PK. All rights reserved.
"""

import os
from pathlib import Path

from pydantic import EmailStr, Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class _EmailConfigs(BaseSettings):
    __ENV_PATH  = (None if os.getenv("VERCEL") == "1" else Path(__file__).parent.joinpath(".env"))

    SMTP_Server:str = Field(default=...,)
    """The SMTP server to use for sending the email."""
    SMTP_Port: int = Field(default=...,)
    """Port of the SMTP Server to use."""
    Email: EmailStr = Field(default=...,)
    """The Email Address"""
    Password: str = Field(default=...,)
    """The password of to your email account."""

    model_config = SettingsConfigDict(
            env_file=__ENV_PATH,
            case_sensitive=True,
            extra="ignore",
        )
    