"""Configuration values for bearer-token authentication."""

from pathlib import Path

from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict

ACCESS_TOKEN_IDLE_TIMEOUT_MINUTES = 15
"""Number of inactive minutes before an access token expires."""

JWT_ALGORITHM = "HS256"
"""The signing algorithm used for access tokens."""


class _AuthSettings(BaseSettings):
    """Load authentication secrets from the environment or configs/.env."""

    JWT_SECRET_KEY: SecretStr | None = None

    model_config = SettingsConfigDict(
        env_file=Path(__file__).parent / ".env",
        case_sensitive=True,
        extra="ignore",
    )


def get_jwt_secret() -> str:
    """Return the configured signing key, rejecting absent or weak keys."""
    secret_setting = _AuthSettings().JWT_SECRET_KEY
    if secret_setting is None:
        raise RuntimeError("JWT_SECRET_KEY must be configured to enable authentication.")
    secret = secret_setting.get_secret_value()
    if len(secret.encode("utf-8")) < 32:
        raise RuntimeError("JWT_SECRET_KEY must contain at least 32 bytes.")
    return secret


__all__ = [
    "ACCESS_TOKEN_IDLE_TIMEOUT_MINUTES",
    "JWT_ALGORITHM",
    "get_jwt_secret",
]
