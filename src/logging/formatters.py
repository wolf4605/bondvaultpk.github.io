"""Console and file log message formatters."""

import json
import logging
from datetime import datetime
from typing import Literal

from rich.cells import cell_len

from .theme import LEVEL_SCHEMES, MODULE_COLORS
from .utils import get_timezone


class EmojiFormatter(logging.Formatter):
    """Compact terminal formatter with emojis and module-aware colored labels."""

    def __init__(
        self,
        fmt=None,
        datefmt=None,
        style: Literal["%", "{", "$"] = "%",
        use_markup=False,
    ):
        """Initialise the formatter and whether the message should use rich markup."""
        super().__init__(fmt, datefmt, style)
        self.use_markup = use_markup

    def format(self, record):
        """Format a log record with timestamp, level label, module name, and emoji."""
        emoji, color, level_label = LEVEL_SCHEMES.get(
            record.levelno, ("•", "white", record.levelname.upper())
        )
        emoji = emoji.rstrip()
        original_message = record.msg

        if record.name.startswith("uvicorn."):
            module_name = "uvicorn"
        else:
            module_name = record.name.split(".")[-1] if record.name else "root"

        module_parts = record.name.split(".") if record.name else ["root"]
        module_key = next(
            (part for part in module_parts if part in MODULE_COLORS), "default"
        )
        module_color = MODULE_COLORS[module_key]
        timestamp = datetime.now(get_timezone()).strftime("%H:%M:%S")

        if self.use_markup:
            message_indent = sum(
                cell_len(part)
                for part in (
                    timestamp,
                    " ",
                    f"{level_label:<8}",
                    " ",
                    f"{module_name:<15}",
                    " ",
                    emoji,
                    "  ",
                )
            )
            prefix = (
                f"[log.timestamp]{timestamp}[/] "
                f"[{color}]{level_label:<8}[/] "
                f"[{module_color}]{module_name:<15}[/] {emoji}  "
            )
            message = "\n".join(
                f"{' ' * message_indent if index else ''}[{color}]{line}[/]"
                for index, line in enumerate(str(original_message).split("\n"))
            )
            record.msg = f"{prefix}{message}"
        else:
            message_indent = sum(
                cell_len(part)
                for part in (
                    timestamp,
                    " | ",
                    f"{module_name:<15}",
                    " | ",
                    f"{level_label:<8}",
                    " | ",
                    emoji,
                    "  ",
                )
            )
            message = str(original_message).replace("\n", "\n" + " " * message_indent)
            record.msg = (
                f"{timestamp} | {module_name:<15} | {level_label:<8} | "
                f"{emoji}  {message}"
            )

        result = super().format(record)
        record.msg = original_message
        return result


class JSONFormatter(logging.Formatter):
    """Formatter that renders log records as JSON for structured file logging."""

    def format(self, record):
        """Convert the record into a JSON payload while preserving exception details."""
        payload = {
            "timestamp": datetime.fromtimestamp(
                record.created, tz=get_timezone()
            ).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "module": record.module,
            "function": record.funcName,
            "line": record.lineno,
            "message": record.getMessage(),
        }

        for key, value in record.__dict__.items():
            if key in {
                "name",
                "msg",
                "args",
                "levelname",
                "levelno",
                "pathname",
                "filename",
                "module",
                "exc_info",
                "exc_text",
                "stack_info",
                "lineno",
                "funcName",
                "created",
                "msecs",
                "relativeCreated",
                "thread",
                "threadName",
                "processName",
                "process",
                "message",
                "asctime",
            }:
                continue
            if key.startswith("_"):
                continue
            payload[key] = value

        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)

        return json.dumps(payload, default=str, ensure_ascii=False)
