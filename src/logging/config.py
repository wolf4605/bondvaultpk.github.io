"""
* Project Name: BONDVAULT PK

* Description: Logging configuration used to bootstrap the application runtime.

This module defines the global logging structure: the console handler, the rotating file handler, custom filters, and the dictionary configuration passed to ``logging.config``. Separating the configuration keeps the application startup code straightforward while remaining easy to tune when log retention or routing requirements change.

* Author: Wolf4605
* Email: mab4605@gmail.com

* Date: 2026-10-20 18:28:57

* Last Modified by: Wolf4605
* Last Modified time: 2026-10-21 20:06:08

* License: MIT
* Copyright© BondVault PK. All rights reserved.
"""

import glob
import os
from datetime import datetime

from rich.highlighter import NullHighlighter

from .. import configs
from .formatters import EmojiFormatter
from .handlers import (
    HeaderRotatingFileHandler,
    SuppressUvicornAccessFilter,
    SuppressUvicornASGIExceptionFilter,
    TerminalSilentTracebackHandler,
)
from .theme import RichConsole
from .utils import get_timezone

# Base directory where rotated application logs are stored.
IS_VERCEL = os.getenv("VERCEL") == "1"

LOG_DIR = "/tmp/logs" if IS_VERCEL else "logs"

# Number of rotated files to keep before pruning the oldest files.
MAX_LOG_FILES = configs.MAX_LOG_FILES

# Maximum size of each log file before the rotating handler rolls it over.
MAX_FILE_SIZE = configs.MAX_LOG_FILE_SIZE

# Allow request logging to be selectively enabled for a small whitelist of routes.
REQUEST_LOG_WHITELIST = {("POST", "/users")}


def get_next_log_filename() -> str:
    """Create the next log file and remove the oldest log files when the limit is exceeded."""
    os.makedirs(LOG_DIR, exist_ok=True)
    existing_logs = sorted(
        glob.glob(os.path.join(LOG_DIR, "log_*.log"))
        + glob.glob(os.path.join(LOG_DIR, "log_*.txt")),
        key=os.path.getctime,
    )

    while len(existing_logs) >= MAX_LOG_FILES:
        oldest_file = existing_logs.pop(0)
        try:
            os.remove(oldest_file)
        except OSError:
            pass

    timestamp = datetime.now(get_timezone()).strftime("%Y-%m-%d_%H-%M-%S")
    return os.path.join(LOG_DIR, f"log_{timestamp}.txt")


# Create a dedicated log file for the current process startup.
CURRENT_LOG_FILE = get_next_log_filename()


LOGGING_CONFIG = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "minimal": {
            "()": EmojiFormatter,
            "format": "%(message)s",
            "datefmt": "%H:%M:%S",
            "use_markup": True,
        },
        "text": {
            "format": "%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
            "datefmt": "%Y-%m-%d %H:%M:%S",
        },
    },
    "handlers": {
        "console": {
            "()": TerminalSilentTracebackHandler,
            "formatter": "minimal",
            "level": "INFO",
            "filters": ["suppress_uvicorn_asgi"],
            "rich_tracebacks": True,
            "show_time": False,
            "show_level": False,
            "show_path": False,
            "omit_repeated_times": True,
            "markup": True,
            "highlighter": NullHighlighter(),
            "console": RichConsole,
        },
        "file": {
            "()": HeaderRotatingFileHandler,
            "formatter": "text",
            "level": "DEBUG",
            "filters": ["suppress_uvicorn_asgi"],
            "filename": CURRENT_LOG_FILE,
            "maxBytes": MAX_FILE_SIZE,
            "backupCount": 0,
            "mode": "w",
            "encoding": "utf8",
        },
    },
    "filters": {
        "suppress_uvicorn_asgi": {
            "()": SuppressUvicornASGIExceptionFilter,
        },
        "suppress_uvicorn_access": {
            "()": SuppressUvicornAccessFilter,
        },
    },
    "loggers": {
        "": {
            "handlers": ["console", "file"],
            "level": "DEBUG",
        },
        "application.errors": {
            "handlers": ["file"],
            "level": "ERROR",
            "propagate": False,
        },
        "application.error_indicator": {
            "handlers": ["console"],
            "level": "ERROR",
            "propagate": False,
        },
        "application.audit": {
            "handlers": ["file"],
            "level": "INFO",
            "propagate": False,
        },
        "uvicorn": {
            "handlers": ["console", "file"],
            "level": "INFO",
            "propagate": False,
        },
        "uvicorn.access": {
            "handlers": ["console", "file"],
            "filters": ["suppress_uvicorn_access"],
            "level": "INFO",
            "propagate": False,
        },
        "uvicorn.error": {
            "handlers": ["console", "file"],
            "filters": ["suppress_uvicorn_asgi"],
            "level": "INFO",
            "propagate": False,
        },
    },
}


def print_startup_banner() -> None:
    """Print the application startup banner in the rich console."""
    banner = r"""
    ╔══════════════════════════════════════════════════════════════════════╗
    ║                     PRIZE BOND CHECKING SERVICE                      ║
    ║                         SYSTEM BOOTING UP                            ║
    ╚══════════════════════════════════════════════════════════════════════╝
    """
    RichConsole.print(banner, style="bold bright_cyan")
