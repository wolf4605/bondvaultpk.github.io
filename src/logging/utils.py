"""Logging utility functions and helpers."""

import datetime as dt
from datetime import datetime, tzinfo


def get_timezone() -> tzinfo:
    """Get the local timezone."""
    local_tz = datetime.now().astimezone().tzinfo
    return local_tz if local_tz else dt.UTC
