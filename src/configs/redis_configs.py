"""Configuration values for the Redis session store."""

from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class _RedisSettings(BaseSettings):
    """Load the Redis connection URL from the environment or configs/.env."""

    REDIS_URL: str = "redis://localhost:6379/0"

    model_config = SettingsConfigDict(
        env_file=Path(__file__).parent / ".env",
        case_sensitive=True,
        extra="ignore",
    )


def get_redis_url() -> str:
    """Return the configured Redis connection URL."""
    return _RedisSettings().REDIS_URL


__all__ = ["get_redis_url"]
