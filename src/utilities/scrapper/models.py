"""Data models returned by the prize bond scraper."""

from collections.abc import Sequence
from dataclasses import dataclass
from datetime import date
from typing import Protocol


@dataclass(frozen=True)
class PrizeBondDrawResult:
    """A result file and the date of the draw it belongs to."""

    draw_date: date
    url: str
    file_type: str
    can_auto_import: bool = False


@dataclass
class PrizeBondResults:
    """Draw result files grouped under one prize bond denomination."""

    denomination: int
    results: list[PrizeBondDrawResult]


@dataclass(frozen=True)
class PrizeBondTextResult:
    """Top-tier winning numbers parsed from one text draw result."""

    denomination: int
    draw_date: date
    url: str
    first_prize_numbers: tuple[str, ...]
    second_prize_numbers: tuple[str, ...]
    third_prize_numbers: tuple[str, ...]
    error: str | None = None


class PrizeBondScraper(Protocol):
    """Common interface for configured prize-bond result sources."""

    async def fetch_draw_result_links(self) -> list[PrizeBondResults]: ...

    async def fetch_text_draw_results(
        self,
        drawlist_results: Sequence[PrizeBondResults] | None = None,
    ) -> list[PrizeBondTextResult]: ...
