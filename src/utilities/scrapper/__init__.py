"""Prize bond draw-list scraping utilities."""

from .client import PrizeBondClient
from .models import (
    PrizeBondDrawResult,
    PrizeBondResults,
    PrizeBondScraper,
    PrizeBondTextResult,
)
from .source2_client import PrizeBondPKClient


def create_prize_bond_client() -> PrizeBondScraper:
    """Create the configured scraper implementation."""
    from ...configs import ScraperConfigs

    if ScraperConfigs.SCRAPER_SOURCE == "national_savings":
        return PrizeBondClient()
    if ScraperConfigs.SCRAPER_SOURCE == "prizebondpk":
        return PrizeBondPKClient()
    raise ValueError(
        f"Unsupported prize-bond scraper source: {ScraperConfigs.SCRAPER_SOURCE}"
    )


__all__ = [
    "PrizeBondClient",
    "PrizeBondDrawResult",
    "PrizeBondPKClient",
    "PrizeBondResults",
    "PrizeBondScraper",
    "PrizeBondTextResult",
    "create_prize_bond_client",
]
