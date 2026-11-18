"""General utility functions and helpers."""

import io
import sys
from typing import cast


class _Console:

    def reconfigure_encoding(self) -> None:
        """Reconfigure the encoding of the console."""
        stdout = cast(io.TextIOWrapper, sys.stdout)
        stderr = cast(io.TextIOWrapper, sys.stderr)
        if hasattr(sys.stdout, "reconfigure"):
            stdout.reconfigure(encoding="utf-8")

        if hasattr(sys.stderr, "reconfigure"):
            stderr.reconfigure(encoding="utf-8")

Console = _Console()