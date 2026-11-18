"""Rich console formatting theme styles."""
from rich.console import Console
from rich.theme import Theme

# Rich style names used by the console formatter.
LEVEL_SCHEMES = {
    10: ("🐛 ", "logging.level.debug", "DEBUG"),
    20: ("ℹ️ ", "logging.level.info", "INFO"),
    25: ("✔️ ", "logging.level.success", "SUCCESS"),
    30: ("⚠️ ", "logging.level.warning", "WARNING"),
    35: ("❌ ", "logging.level.fail", "FAIL"),
    40: ("🚨 ", "logging.level.error", "ERROR"),
    50: ("🔥 ", "logging.level.critical", "CRITICAL"),
}

MODULE_COLORS = {
    "root": "log.module.root",
    "app": "log.module.app",
    "main": "log.module.main",
    "automation": "log.module.automation",
    "database": "log.module.database",
    "configs": "log.module.configs",
    "routers": "log.module.routers",
    "responses": "log.module.responses",
    "errors": "log.module.errors",
    "uvicorn": "log.module.uvicorn",
    "default": "log.module.default",
}

# Theme used for the rich console. This keeps the terminal output consistent across the app.
_custom_theme = Theme(
    {
        "logging.level.debug": "bold dim cyan",
        "logging.level.info": "yellow",
        "logging.level.warning": "bold reverse yellow",
        "logging.level.error": "bold bright_red",
        "logging.level.critical": "bold reverse red",
        "logging.level.success": "bold green",
        "logging.level.fail": "bold red",
        "log.timestamp": "dim",
        "log.level": "bold",
        "log.module.root": "bold cyan",
        "log.module.app": "bold cyan",
        "log.module.main": "bold magenta",
        "log.module.automation": "bold green",
        "log.module.database": "bold blue",
        "log.module.configs": "bold cyan",
        "log.module.routers": "bold yellow",
        "log.module.responses": "bold bright_magenta",
        "log.module.errors": "bold red",
        "log.module.uvicorn": "bold cyan",
        "log.module.default": "bold cyan",
    }
)

# Shared console instance used by the logging system.
RichConsole: Console = Console(theme=_custom_theme, force_terminal=True)

__all__ = ["LEVEL_SCHEMES", "MODULE_COLORS", "RichConsole"]
