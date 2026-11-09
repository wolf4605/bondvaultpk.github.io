"""
* Project Name: BONDVAULT PK

* Description: Contains all the Configurations Required in the application.

* Author: Wolf4605
* Email: mab4605@gmail.com

* Date: 2026-10-20 17:39:33

* Last Modified by: Wolf4605
* Last Modified time: 2026-10-21 20:10:32

* License: MIT
* Copyright© BondVault PK. All rights reserved.
"""

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