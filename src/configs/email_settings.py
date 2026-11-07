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

from pydantic import EmailStr, Field, SecretStr, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class _EmailConfigs(BaseSettings):
    __ENV_PATH  = (None if os.getenv("VERCEL") == "1" else Path(__file__).parent.joinpath(".env"))

    SMTP_Server: str | None = None
    """The SMTP server to use for sending the email."""
    SMTP_Port: int | None = Field(default=None, ge=1, le=65535)
    """Port of the SMTP Server to use."""
    Email: EmailStr | None = None
    """The Email Address"""
    Password: SecretStr | None = None
    """The password or app password of your email account."""

    @field_validator("SMTP_Server")
    @classmethod
    def validate_smtp_server(cls, value: str | None) -> str | None:
        """Require a bare SMTP hostname, without a scheme, path, or port."""
        if value is None:
            return None
        hostname = value.strip()
        if (
            not hostname
            or "://" in hostname
            or any(character in hostname for character in "/:@ \t\r\n")
        ):
            raise ValueError(
                "SMTP_Server must be a hostname such as smtp.gmail.com, "
                "without a URL scheme or port."
            )
        return hostname

    @field_validator("SMTP_Port")
    @classmethod
    def validate_smtp_port(cls, value: int | None) -> int | None:
        """Allow standard SMTP submission ports with the configured TLS mode."""
        if value is not None and value not in {25, 465, 587, 2525}:
            raise ValueError("SMTP_Port must be one of 25, 465, 587, or 2525.")
        return value

    model_config = SettingsConfigDict(
            env_file=__ENV_PATH,
            case_sensitive=True,
            extra="ignore",
        )
    