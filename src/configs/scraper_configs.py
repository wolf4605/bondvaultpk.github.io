"""Configuration for selecting the prize-bond result source."""

import os
from pathlib import Path
from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict

_ENV_PATH = (
    None
    if os.getenv("VERCEL") == "1"
    else Path(__file__).parent.joinpath(".env")
)


class _ScraperConfigs(BaseSettings):
    """Choose the scraper implementation used by draw-list automation."""

    SCRAPER_SOURCE: Literal["national_savings", "prizebondpk"] = "national_savings"

    model_config = SettingsConfigDict(
        env_file=_ENV_PATH,
        case_sensitive=True,
        extra="ignore",
    )


ScraperConfigs = _ScraperConfigs()
