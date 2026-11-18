"""Logger factory and instance resolution helpers."""

import inspect
import logging
import logging.config

from ..utilities import Console
from .config import LOGGING_CONFIG, REQUEST_LOG_WHITELIST, print_startup_banner

# Custom log level for successful operations.
LEVEL_SUCCESS = 25

# Custom log level for failed operations.
LEVEL_FAIL = 35

# Register the custom names so they appear correctly in formatted output.
logging.addLevelName(LEVEL_SUCCESS, "SUCCESS")
logging.addLevelName(LEVEL_FAIL, "FAIL")


class CustomLogger(logging.Logger):
    """Typed logger with convenience helpers for success and failure events."""

    def success(self, message, *args, **kwargs):
        """Log a success event at the custom success level."""
        if self.isEnabledFor(LEVEL_SUCCESS):
            self._log(LEVEL_SUCCESS, message, args, **kwargs)

    def fail(self, message, *args, **kwargs):
        """Log a failure event at the custom failure level."""
        if self.isEnabledFor(LEVEL_FAIL):
            self._log(LEVEL_FAIL, message, args, **kwargs)


logging.setLoggerClass(CustomLogger)


def setup_logging() -> None:
    """Apply the global logging configuration and print the startup banner."""
    Console.reconfigure_encoding()
    logging.config.dictConfig(LOGGING_CONFIG)
    print_startup_banner()


def get_logger() -> CustomLogger:
    """Return a logger configured for the calling module."""
    caller_frame = inspect.stack()[1][0]
    caller_module = inspect.getmodule(caller_frame)
    logger_name = caller_module.__name__ if caller_module else "app"
    logger = logging.getLogger(logger_name)
    if not isinstance(logger, CustomLogger):
        logger.__class__ = CustomLogger
    return logger  # type: ignore[return-value]


def request_log(
    logger: logging.Logger,
    *,
    method: str,
    path: str,
    status_code: int,
    duration_ms: float,
    extra: dict | None = None,
) -> None:
    """Emit a structured request log entry for HTTP traffic."""
    details = {
        "event": "http.request",
        "method": method.upper(),
        "path": path,
        "status_code": status_code,
        "duration_ms": round(duration_ms, 3),
    }
    if extra:
        details.update(extra)
    logger.info("request completed", extra=details)


def should_log_request(method: str, path: str) -> bool:
    """Return whether the request matches an explicitly logged whitelist entry."""
    return (method.upper(), path) in REQUEST_LOG_WHITELIST
