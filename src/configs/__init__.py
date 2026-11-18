"""Application configuration package."""

from .app_settings import AppSettings
from .auth_configs import ACCESS_TOKEN_IDLE_TIMEOUT_MINUTES, JWT_ALGORITHM
from .db_configs import AdminDBConfigs, DBConfigs
from .prize_bonds import (
    PRIZE_POSITION_NAMES,
    PrizeBondDenominations,
)
from .scraper_configs import ScraperConfigs

MAX_LOG_FILES: int = 3
"""Maximum number of log files to keep."""
MAX_LOG_FILE_SIZE: int = 10 * 1024 * 1024  # 10 MB
"""Maximum size of a log file."""
DRAW_LISTS_URL = "https://savings.gov.pk/download-draws/"

__all__ = [
    "MAX_LOG_FILES",
    "MAX_LOG_FILE_SIZE",
    "AdminDBConfigs",
    "ACCESS_TOKEN_IDLE_TIMEOUT_MINUTES",
    "AppSettings",
    "DBConfigs",
    "JWT_ALGORITHM",
    "PRIZE_POSITION_NAMES",
    "PrizeBondDenominations",
    "ScraperConfigs",

]