"""File and stream logging handlers."""

import logging
from datetime import datetime
from logging.handlers import RotatingFileHandler

from rich.logging import RichHandler

from .utils import get_timezone


class TerminalSilentTracebackHandler(RichHandler):
    """Rich console handler that suppresses duplicate uvicorn traceback noise."""

    def emit(self, record):
        """Emit the record to the rich console while filtering duplicate traceback noise."""
        if "Exception in ASGI application" in str(record.msg):
            return

        if record.exc_info:
            original_exc_info = record.exc_info
            original_exc_text = getattr(record, "exc_text", None)

            record.exc_info = None
            record.exc_text = None

            try:
                super().emit(record)
            finally:
                record.exc_info = original_exc_info
                if original_exc_text is not None:
                    record.exc_text = original_exc_text
        else:
            super().emit(record)


class SuppressUvicornASGIExceptionFilter(logging.Filter):
    """Filter that suppresses duplicate ASGI error records emitted by uvicorn."""

    def filter(self, record):
        """Return ``False`` when the record is the duplicate uvicorn ASGI exception."""
        return not (
            record.name == "uvicorn.error"
            and "Exception in ASGI application" in record.getMessage()
        )


class SuppressUvicornAccessFilter(logging.Filter):
    """Filter that disables the blanket access logs emitted by uvicorn."""

    def filter(self, record):
        """Return ``False`` for uvicorn access logs unless they are explicitly enabled."""
        return False


class HeaderRotatingFileHandler(RotatingFileHandler):
    """Rotating file handler that writes a log banner when a file starts or rotates."""

    def __init__(self, *args, **kwargs):
        """Initialise the handler and immediately write a banner to the file."""
        super().__init__(*args, **kwargs)
        self._write_header()

    def _write_header(self):
        """Write a visible startup banner at the beginning of each log file."""
        timestamp = datetime.now(get_timezone()).strftime("%Y-%m-%d %H:%M:%S")
        border = "╔══════════════════════════════════════════════════════════════════════════╗"
        inner_width = len(border) - 2
        message = f"--- LOG START / LOG RESET / TRUNCATED AT {timestamp} ---"
        banner = f"{border}\n║{message:^{inner_width}}║\n╚{'═' * inner_width}╝\n\n"
        with open(self.baseFilename, "a", encoding=self.encoding) as file_handle:
            file_handle.write(banner)

    def doRollover(self):
        """Perform file rollover and re-write the banner to the new log file."""
        super().doRollover()
        self._write_header()
