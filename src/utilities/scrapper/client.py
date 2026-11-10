"""Async HTTP client for prize bond draw-list pages and text results."""

import asyncio
import ssl
from collections.abc import Sequence

import httpx

from ...configs import DRAW_LISTS_URL
from ...logging import get_logger
from .models import (
    PrizeBondDrawResult,
    PrizeBondResults,
    PrizeBondTextResult,
)
from .parsers import (
    _decode_text_file,
    _extract_drawlist_links,
    _parse_prize_numbers,
    _parse_result_links,
)
from .tls import create_scraper_ssl_context

logger = get_logger()
REQUEST_RETRIES = 3
RETRY_DELAY_SECONDS = 0.5


class PrizeBondClient:
    """Fetch prize bond draw-list page links from National Savings Pakistan."""

    def __init__(
        self,
        *,
        draw_lists_url: str = DRAW_LISTS_URL,
        timeout: float = 10.0,
        transport: httpx.AsyncBaseTransport | None = None,
        verify: bool | ssl.SSLContext | None = None,
    ) -> None:
        self.draw_lists_url = draw_lists_url
        self.verify = verify
        self.timeout = timeout
        self.transport = transport

    async def fetch_drawlist_links(self) -> dict[int, str]:
        """Return a mapping of bond denomination in rupees to draw-list URL."""
        async with httpx.AsyncClient(
            timeout=self.timeout,
            follow_redirects=True,
            transport=self.transport,
            verify=self.verify,
        ) as client:
            return await _fetch_drawlist_links(client, self.draw_lists_url)

    async def fetch_draw_result_links(self) -> list[PrizeBondResults]:
        """Return result files grouped by denomination, including their draw dates."""
        async with httpx.AsyncClient(
            timeout=self.timeout,
            follow_redirects=True,
            transport=self.transport,
            verify=self.verify,
        ) as client:
            drawlist_links = await _fetch_drawlist_links(client, self.draw_lists_url)
            results_by_denomination = await asyncio.gather(
                *(
                    _fetch_result_links(client, drawlist_url)
                    for drawlist_url in drawlist_links.values()
                )
            )

        return [
            PrizeBondResults(denomination, results)
            for denomination, results in zip(
                drawlist_links,
                results_by_denomination,
                strict=True,
            )
        ]

    async def fetch_text_draw_results(
        self,
        drawlist_results: Sequence[PrizeBondResults] | None = None,
    ) -> list[PrizeBondTextResult]:
        """Parse linked text files; per-file fetch or parse errors are returned."""
        if drawlist_results is None:
            drawlist_results = await self.fetch_draw_result_links()
        text_results = [
            (drawlist.denomination, result)
            for drawlist in drawlist_results
            for result in drawlist.results
            if result.file_type == "txt"
        ]

        async with httpx.AsyncClient(
            timeout=self.timeout,
            follow_redirects=True,
            transport=self.transport,
            verify=self.verify,
        ) as client:
            return list(
                await asyncio.gather(
                    *(
                        _fetch_text_result(client, denomination, result)
                        for denomination, result in text_results
                    )
                )
            )


async def _fetch_drawlist_links(
    client: httpx.AsyncClient,
    draw_lists_url: str,
) -> dict[int, str]:
    response = await _get_with_retries(client, draw_lists_url)
    response.raise_for_status()
    return _extract_drawlist_links(response.content, str(response.url))


async def _fetch_result_links(
    client: httpx.AsyncClient,
    drawlist_url: str,
) -> list[PrizeBondDrawResult]:
    response = await _get_with_retries(client, drawlist_url)
    response.raise_for_status()
    return _parse_result_links(response.content, str(response.url))


async def _fetch_text_result(
    client: httpx.AsyncClient,
    denomination: int,
    result: PrizeBondDrawResult,
) -> PrizeBondTextResult:
    try:
        response = await _get_with_retries(client, result.url)
        response.raise_for_status()
    except httpx.HTTPError as error:
        return _failed_text_result(denomination, result, str(error))

    try:
        first, second, third = _parse_prize_numbers(
            _decode_text_file(response.content),
            denomination,
        )
    except ValueError as error:
        return _failed_text_result(denomination, result, str(error))

    missing_prizes = [
        prize_name
        for prize_name, numbers in (
            ("first", first),
            ("second", second),
            ("third", third),
        )
        if not numbers
    ]
    if missing_prizes:
        return _failed_text_result(
            denomination,
            result,
            f"Could not extract {', '.join(missing_prizes)} prize numbers",
        )

    return PrizeBondTextResult(
        denomination=denomination,
        draw_date=result.draw_date,
        url=result.url,
        first_prize_numbers=first,
        second_prize_numbers=second,
        third_prize_numbers=third,
    )


def _failed_text_result(
    denomination: int,
    result: PrizeBondDrawResult,
    error: str,
) -> PrizeBondTextResult:
    return PrizeBondTextResult(
        denomination=denomination,
        draw_date=result.draw_date,
        url=result.url,
        first_prize_numbers=(),
        second_prize_numbers=(),
        third_prize_numbers=(),
        error=error,
    )


async def _get_with_retries(
    client: httpx.AsyncClient,
    url: str,
) -> httpx.Response:
    """Retry transient transport failures without weakening TLS verification."""
    for attempt in range(REQUEST_RETRIES):
        try:
            return await client.get(url)
        except httpx.TransportError as error:
            if attempt == REQUEST_RETRIES - 1:
                raise
            delay = RETRY_DELAY_SECONDS * (2**attempt)
            logger.warning(
                "Transient draw-list connection failure; retrying "
                "(attempt=%s/%s, delay_seconds=%s, url=%s): %s",
                attempt + 1,
                REQUEST_RETRIES,
                delay,
                url,
                error,
            )
            await asyncio.sleep(delay)
    raise RuntimeError("The draw-list request retry loop exited unexpectedly.")
