"""Database connection configuration and environment settings."""
import os
from pathlib import Path

from pydantic import Field, computed_field
from pydantic_settings import BaseSettings, SettingsConfigDict


class _Base(BaseSettings):
    __ENV_PATH  = (None if os.getenv("VERCEL") == "1" else Path(__file__).parent.joinpath(".env"))
    DB_MIN_CONNECTIONS: int = 5
    """Minimum number of database connections allowed in the pool."""
    DB_MAX_CONNECTIONS: int = 10
    """Maximum number of database connections allowed in the pool."""
    DB_TIMEOUT: float = 30.0
    """Seconds allowed for opening a pool connection."""
    DB_COMMAND_TIMEOUT: float | None = None
    """Individual command timeout for database functions."""

    model_config = SettingsConfigDict(
        env_file=__ENV_PATH,
        case_sensitive=True,
        extra="ignore",
    )

class _DBConfigs(_Base):
    """Stores Critical Database Settings."""

    POSTGRES_USER: str = Field(default=...)
    """Username for the DB."""
    POSTGRES_PASSWORD: str = Field(default=...)
    """Password for the DB."""
    POSTGRES_HOST: str = Field(default=...)
    """Host the DB is using for Connections."""
    POSTGRES_PORT: int = Field(default=...)
    """Port the DB is using for Connections."""
    POSTGRES_DB: str = Field(default=...)
    """Name of the Database."""

    @computed_field
    @property
    def CONNECTION_STRING(self) -> str:
        """Connection String for the database."""
        return f"postgresql://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}@{self.POSTGRES_HOST}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"
    
class _AdminDBConfigs(_Base):
    """Stores Administrator Database Settings will only be used if `initialize_db` is `true` in `pyproject.toml`."""

    ADMIN_POSTGRES_USER: str|None = Field(default=None)
    """Username for the DB."""
    ADMIN_POSTGRES_PASSWORD: str|None = Field(default=None)
    """Password for the DB."""
    POSTGRES_HOST: str = Field(default=...)
    """Host the DB is using for Connections."""
    POSTGRES_PORT: int = Field(default=...)
    """Port the DB is using for Connections."""
    POSTGRES_DB: str = Field(default=...)
    """Name of the Database."""

    @computed_field
    @property
    def CONNECTION_STRING(self) -> str:
        """Connection String for the database."""
        return f"postgresql://{self.ADMIN_POSTGRES_USER}:{self.ADMIN_POSTGRES_PASSWORD}@{self.POSTGRES_HOST}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"
    
DBConfigs = _DBConfigs()
AdminDBConfigs = _AdminDBConfigs()