
# @Author: BondVault PK
# @Date:   2026-11-07 19:40:34
# @Last Modified by:   Wolf4605
# @Last Modified time: 2026-11-07 20:22:28
"""Scrape prize-bond draw results and future draw dates from PrizeBondPK."""

import asyncio
import re
import time
from collections.abc import Iterator, Sequence
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import date, datetime, timezone
from html.parser import HTMLParser
from typing import TypedDict
from urllib.error import HTTPError, URLError
from urllib.parse import urljoin, urlparse
from urllib.request import Request, urlopen

from ...logging import get_logger
from .models import (
    PrizeBondDrawResult,
    PrizeBondResults,
    PrizeBondTextResult,
    ScheduledDraw,
)
from .tls import create_scraper_ssl_context

logger = get_logger()
REQUEST_RETRIES = 3
RETRY_DELAY_SECONDS = 0.5

SITE_URL = "https://prizebondpk.com/"
SITEMAP_URL = urljoin(SITE_URL, "sitemap/")
DRAW_PATH = re.compile(
    r"^/prize-bond-denominations/rs-(\d+)/draw-(\d+)/?$", re.IGNORECASE
)
SCHEDULE_PATH = re.compile(r"^/prize-bond-draw-schedule-(\d{4})/?$", re.IGNORECASE)
VOID_TAGS = {
    "area",
    "base",
    "br",
    "col",
    "embed",
    "hr",
    "img",
    "input",
    "link",
    "meta",
    "param",
    "source",
    "track",
    "wbr",
}


class PrizeTier(TypedDict):
    amount: str
    numbers: list[str]


class DrawResult(TypedDict):
    denomination: int
    draw_number: int
    draw_date: str
    city: str
    url: str
    prizes: dict[str, PrizeTier]


class ScrapeError(TypedDict):
    url: str
    error: str


class ScrapeOutput(TypedDict):
    source: str
    scraped_at: str
    draw_results: list[DrawResult]
    upcoming_draws: list[ScheduledDraw]
    errors: list[ScrapeError]


class Element:
    """A small HTML node used to inspect result pages without third-party packages."""

    def __init__(self, tag: str, attrs: dict[str, str]) -> None:
        self.tag = tag
        self.attrs = attrs
        self.children: list[Element|str] = []

    def descendants(
        self, tag: str|None = None, class_name: str|None = None
    ) -> Iterator["Element"]:
        for child in self.children:
            if not isinstance(child, Element):
                continue
            classes = child.attrs.get("class", "").split()
            if (tag is None or child.tag == tag) and (
                class_name is None or class_name in classes
            ):
                yield child
            yield from child.descendants(tag, class_name)

    def text(self) -> str:
        parts: list[str] = []
        for child in self.children:
            parts.append(child.text() if isinstance(child, Element) else child)
        return " ".join(" ".join(parts).split())


class DocumentParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.root = Element("document", {})
        self.stack = [self.root]

    def handle_starttag(
        self, tag: str, attrs: list[tuple[str, str|None]]
    ) -> None:
        element = Element(tag, {key: value or "" for key, value in attrs})
        self.stack[-1].children.append(element)
        if tag not in VOID_TAGS:
            self.stack.append(element)

    def handle_startendtag(
        self, tag: str, attrs: list[tuple[str, str|None]]
    ) -> None:
        self.handle_starttag(tag, attrs)
        if tag not in VOID_TAGS:
            self.handle_endtag(tag)

    def handle_endtag(self, tag: str) -> None:
        for index in range(len(self.stack) - 1, 0, -1):
            if self.stack[index].tag == tag:
                del self.stack[index:]
                return

    def handle_data(self, data: str) -> None:
        self.stack[-1].children.append(data)


class SitemapLinkParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.links: list[str] = []
        self._href: str|None = None
        self._anchor_depth = 0

    def handle_starttag(
        self, tag: str, attrs: list[tuple[str, str|None]]
    ) -> None:
        if tag != "a":
            return
        attributes = dict(attrs)
        if self._anchor_depth == 0:
            self._href = attributes.get("href")
        self._anchor_depth += 1

    def handle_endtag(self, tag: str) -> None:
        if tag != "a" or self._anchor_depth == 0:
            return
        self._anchor_depth -= 1
        if self._anchor_depth == 0:
            if self._href:
                self.links.append(self._href)
            self._href = None


def fetch_html(url: str, timeout: int = 30) -> str:
    request = Request(
        url,
        headers={
            "User-Agent": "PrizeBondScraper/1.0 (+https://prizebondpk.com/)",
            "Accept": "text/html,application/xhtml+xml",
        },
    )
    ssl_context = create_scraper_ssl_context()
    for attempt in range(REQUEST_RETRIES):
        try:
            with urlopen(request, timeout=timeout, context=ssl_context) as response:
                return response.read().decode("utf-8", "replace")
        except HTTPError:
            raise
        except (URLError, OSError, TimeoutError) as error:
            if attempt == REQUEST_RETRIES - 1:
                raise
            delay = RETRY_DELAY_SECONDS * (2**attempt)
            logger.warning(
                "Transient PrizeBondPK connection failure; retrying "
                "(attempt=%s/%s, delay_seconds=%s, url=%s): %s",
                attempt + 1,
                REQUEST_RETRIES,
                delay,
                url,
                error,
            )
            time.sleep(delay)
    raise RuntimeError("The PrizeBondPK request retry loop exited unexpectedly.")


def discover_site_urls(
    sitemap_html: str, sitemap_url: str = SITEMAP_URL
) -> tuple[list[str], list[str]]:
    """Find every draw result and yearly schedule linked from the HTML sitemap."""
    parser = SitemapLinkParser()
    parser.feed(sitemap_html)
    draw_urls = set()
    schedule_urls = set()
    sitemap_host = urlparse(sitemap_url).hostname

    for link in parser.links:
        absolute_url = urljoin(sitemap_url, link)
        parsed_url = urlparse(absolute_url)
        if parsed_url.hostname != sitemap_host:
            continue
        path = parsed_url.path
        if DRAW_PATH.match(path):
            draw_urls.add(absolute_url)
        elif SCHEDULE_PATH.match(path):
            schedule_urls.add(absolute_url)

    if not draw_urls:
        raise ValueError("No prize-bond draw links were found in the sitemap.")
    if not schedule_urls:
        raise ValueError("No yearly draw schedule links were found in the sitemap.")
    return sorted(draw_urls), sorted(schedule_urls)


def parse_draw_result(html: str, url: str) -> DrawResult:
    parser = DocumentParser()
    parser.feed(html)
    containers = [
        element
        for element in parser.root.descendants("div")
        if element.attrs.get("id") == "draw-result"
    ]
    if not containers:
        raise ValueError("The page does not contain a draw-result section.")
    container = containers[0]

    url_match = DRAW_PATH.match(urlparse(url).path)
    if not url_match:
        raise ValueError("The result URL does not identify a denomination and draw.")
    denomination = int(url_match.group(1))
    draw_number = int(url_match.group(2))

    title = next(
        (
            element.text()
            for element in container.descendants()
            if "pb-site-title" in element.attrs.get("class", "").split()
        ),
        "",
    )
    title_match = re.search(
        r"Rs\.?\s*([\d,]+).*?Draw\s*#?\s*(\d+)", title, re.IGNORECASE
    )
    if title_match:
        denomination = int(title_match.group(1).replace(",", ""))
        draw_number = int(title_match.group(2))

    prizes: dict[str, PrizeTier] = {}
    for card in container.descendants("div", "pb-draw-card"):
        heading = next(card.descendants("h3"), None)
        if heading is None:
            continue
        prize_name = heading.text()
        amount_element = next(card.descendants("div", "pb-draw-amount"), None)
        amount = amount_element.text() if amount_element else ""
        amount = re.sub(r"^Amount:\s*", "", amount, flags=re.IGNORECASE)
        numbers = [
            element.attrs["data-bond"]
            for element in card.descendants()
            if element.attrs.get("data-bond")
        ]
        prizes[prize_name] = {"amount": amount, "numbers": numbers}
    if not prizes:
        raise ValueError("No winning-number prize tiers were found on the page.")

    draw_date = ""
    city = ""
    for seo_section in container.descendants("div", "pb-site-seo"):
        paragraphs = list(seo_section.descendants("p"))
        if not paragraphs:
            continue
        metadata = paragraphs[0].text()
        match = re.search(
            r"held in\s+(.+?)\s+on\s+(\d{1,2}\s+[A-Za-z]+,?\s+\d{4})",
            metadata,
            re.IGNORECASE,
        )
        if match:
            city = match.group(1).strip()
            draw_date = parse_date(match.group(2)).isoformat()
            break
    if not draw_date or not city:
        raise ValueError("The draw date and city could not be parsed from the result.")

    return {
        "denomination": denomination,
        "draw_number": draw_number,
        "draw_date": draw_date,
        "city": city,
        "url": url,
        "prizes": prizes,
    }


def parse_date(value: str) -> date:
    normalized = " ".join(value.replace(",", " ").split())
    for date_format in ("%d %b %Y", "%d %B %Y", "%Y-%m-%d"):
        try:
            return datetime.strptime(normalized, date_format).date()
        except ValueError:
            continue
    raise ValueError(f"Could not parse schedule date: {value}")


def _header_index(headers: list[str], keywords: tuple[str, ...]) -> int|None:
    for index, header in enumerate(headers):
        if any(keyword in header for keyword in keywords):
            return index
    return None


def parse_schedule_page(
    html: str, url: str, today: date|None = None
) -> list[ScheduledDraw]:
    parser = DocumentParser()
    parser.feed(html)
    today = today or date.today()
    upcoming: list[ScheduledDraw] = []

    for table in parser.root.descendants("table"):
        rows = list(table.descendants("tr"))
        header_index: int|None = None
        headers: list[str] = []
        for index, row in enumerate(rows):
            cells = list(row.descendants("th")) or list(row.descendants("td"))
            normalized = [cell.text().lower().replace("#", "number") for cell in cells]
            combined = " ".join(normalized)
            if "draw" in combined and "date" in combined and (
                "bond" in combined or "denomination" in combined
            ):
                header_index = index
                headers = normalized
                break
        if header_index is None:
            continue

        draw_index = _header_index(headers, ("draw",))
        bond_index = _header_index(headers, ("bond", "denomination"))
        date_index = _header_index(headers, ("date",))
        day_index = _header_index(headers, ("day",))
        city_index = _header_index(headers, ("city",))
        status_index = _header_index(headers, ("status",))
        if draw_index is None or bond_index is None or date_index is None:
            continue

        for row in rows[header_index + 1 :]:
            cells = list(row.descendants("td"))
            required_max = max(draw_index, bond_index, date_index)
            if len(cells) <= required_max:
                continue
            row_values = [cell.text() for cell in cells]
            draw_match = re.search(r"\d+", row_values[draw_index])
            denomination_match = re.search(r"([\d,]+)", row_values[bond_index])
            if draw_match is None or denomination_match is None:
                continue
            scheduled_date = parse_date(row_values[date_index])
            if scheduled_date < today:
                continue
            status = (
                row_values[status_index]
                if status_index is not None and len(row_values) > status_index
                else "Upcoming"
            )

            upcoming.append(
                {
                    "draw_number": int(draw_match.group()),
                    "denomination": int(denomination_match.group().replace(",", "")),
                    "date": scheduled_date.isoformat(),
                    "day": (
                        row_values[day_index]
                        if day_index is not None and len(row_values) > day_index
                        else scheduled_date.strftime("%a")
                    ),
                    "city": (
                        row_values[city_index]
                        if city_index is not None and len(row_values) > city_index
                        else ""
                    ),
                    "status": status,
                    "source_url": url,
                }
            )

    return upcoming


def scrape(
    sitemap_url: str = SITEMAP_URL,
    workers: int = 5,
    today: date|None = None,
) -> ScrapeOutput:
    if workers < 1:
        raise ValueError("The worker count must be at least one.")

    sitemap_html = fetch_html(sitemap_url)
    draw_urls, schedule_urls = discover_site_urls(sitemap_html, sitemap_url)
    draw_results: list[DrawResult] = []
    upcoming_draws: list[ScheduledDraw] = []
    errors: list[ScrapeError] = []

    with ThreadPoolExecutor(max_workers=workers) as executor:
        future_to_url = {
            executor.submit(fetch_html, url): url for url in draw_urls
        }
        for future in as_completed(future_to_url):
            url = future_to_url[future]
            try:
                draw_results.append(parse_draw_result(future.result(), url))
            except (URLError, OSError, ValueError) as error:
                errors.append({"url": url, "error": str(error)})

        schedule_futures = {
            executor.submit(fetch_html, url): url for url in schedule_urls
        }
        for future in as_completed(schedule_futures):
            url = schedule_futures[future]
            try:
                upcoming_draws.extend(
                    parse_schedule_page(future.result(), url, today)
                )
            except (URLError, OSError, ValueError) as error:
                errors.append({"url": url, "error": str(error)})

    draw_results.sort(
        key=lambda item: (int(item["denomination"]), int(item["draw_number"]))
    )
    unique_schedules: dict[tuple[int, int, str], ScheduledDraw] = {
        (
            int(item["denomination"]),
            int(item["draw_number"]),
            str(item["date"]),
        ): item
        for item in upcoming_draws
    }
    sorted_schedules = sorted(
        unique_schedules.values(),
        key=lambda item: (str(item["date"]), int(item["denomination"])),
    )
    errors.sort(key=lambda item: item["url"])

    return {
        "source": sitemap_url,
        "scraped_at": datetime.now(timezone.utc).isoformat(),
        "draw_results": draw_results,
        "upcoming_draws": sorted_schedules,
        "errors": errors,
    }


def scrape_upcoming_draws(
    sitemap_url: str = SITEMAP_URL,
    workers: int = 5,
    today: date | None = None,
) -> list[ScheduledDraw]:
    """Fetch only scheduled draws, without downloading historical results."""
    if workers < 1:
        raise ValueError("The worker count must be at least one.")

    sitemap_html = fetch_html(sitemap_url)
    _, schedule_urls = discover_site_urls(sitemap_html, sitemap_url)
    upcoming_draws: list[ScheduledDraw] = []

    with ThreadPoolExecutor(max_workers=workers) as executor:
        schedule_futures = {
            executor.submit(fetch_html, url): url for url in schedule_urls
        }
        for future in as_completed(schedule_futures):
            url = schedule_futures[future]
            try:
                upcoming_draws.extend(
                    parse_schedule_page(future.result(), url, today)
                )
            except (URLError, OSError, ValueError) as error:
                logger.warning(
                    "Could not scrape PrizeBondPK schedule (url=%s): %s",
                    url,
                    error,
                )

    unique_schedules = {
        (
            int(item["denomination"]),
            int(item["draw_number"]),
            str(item["date"]),
        ): item
        for item in upcoming_draws
    }
    return sorted(
        unique_schedules.values(),
        key=lambda item: (str(item["date"]), int(item["denomination"])),
    )


_PRIZE_TIER_PATTERN = re.compile(
    r"\b(first|1st|second|2nd|third|3rd)\b",
    re.IGNORECASE,
)
_PRIZE_TIER_INDEX = {
    "first": 0,
    "1st": 0,
    "second": 1,
    "2nd": 1,
    "third": 2,
    "3rd": 2,
}
_PRIZE_TIER_NAMES = ("first", "second", "third")


class PrizeBondPKClient:
    """Fetch PrizeBondPK results and expose the common scraper interface."""

    def __init__(self) -> None:
        self._output: ScrapeOutput | None = None
        self._upcoming_draws: list[ScheduledDraw] | None = None
        self._text_results: dict[tuple[int, str], PrizeBondTextResult] = {}

    async def fetch_draw_result_links(self) -> list[PrizeBondResults]:
        """Return PrizeBondPK result pages grouped by denomination."""
        output = await self._load_output()
        self._upcoming_draws = output["upcoming_draws"]
        grouped_results: dict[int, list[PrizeBondDrawResult]] = {}

        for result in output["draw_results"]:
            denomination = int(result["denomination"])
            draw_result = PrizeBondDrawResult(
                draw_date=date.fromisoformat(result["draw_date"]),
                url=result["url"],
                file_type="html",
                can_auto_import=True,
            )
            grouped_results.setdefault(denomination, []).append(draw_result)
            self._text_results[(denomination, result["url"])] = (
                _to_text_result(result)
            )

        return [
            PrizeBondResults(denomination, results)
            for denomination, results in sorted(grouped_results.items())
        ]

    async def fetch_text_draw_results(
        self,
        drawlist_results: Sequence[PrizeBondResults] | None = None,
    ) -> list[PrizeBondTextResult]:
        """Return parsed results using the same model as text-file sources."""
        await self._load_output()
        if drawlist_results is None:
            drawlist_results = await self.fetch_draw_result_links()

        return [
            self._text_results[(drawlist.denomination, result.url)]
            for drawlist in drawlist_results
            for result in drawlist.results
            if (drawlist.denomination, result.url) in self._text_results
        ]

    async def fetch_upcoming_draws(self) -> list[ScheduledDraw]:
        """Fetch upcoming dates from PrizeBondPK without scraping past results."""
        if self._upcoming_draws is None:
            self._upcoming_draws = await asyncio.to_thread(scrape_upcoming_draws)
            logger.info(
                "Scraped PrizeBondPK schedule (upcoming_draws=%s).",
                len(self._upcoming_draws),
            )
        return self._upcoming_draws

    async def _load_output(self) -> ScrapeOutput:
        if self._output is None:
            self._output = await asyncio.to_thread(scrape)
            logger.info(
                "Scraped PrizeBondPK data "
                "(draw_results=%s, upcoming_draws=%s, errors=%s).",
                len(self._output["draw_results"]),
                len(self._output["upcoming_draws"]),
                len(self._output["errors"]),
            )
            for error in self._output["errors"]:
                logger.warning(
                    "Could not scrape PrizeBondPK page (url=%s): %s",
                    error["url"],
                    error["error"],
                )
        return self._output


def _to_text_result(result: DrawResult) -> PrizeBondTextResult:
    prize_numbers: list[tuple[str, ...]] = [(), (), ()]
    found_tiers: set[int] = set()

    for label, prize in result["prizes"].items():
        match = _PRIZE_TIER_PATTERN.search(label)
        if match is not None:
            index = _PRIZE_TIER_INDEX[match.group(1).casefold()]
            found_tiers.add(index)
            prize_numbers[index] = tuple(prize["numbers"])

    seen_numbers: set[str] = set()
    duplicate_numbers: list[str] = []
    for index, numbers in enumerate(prize_numbers):
        unique_numbers = []
        for number in numbers:
            if number in seen_numbers:
                duplicate_numbers.append(number)
                continue
            seen_numbers.add(number)
            unique_numbers.append(number)
        prize_numbers[index] = tuple(unique_numbers)

    if duplicate_numbers:
        logger.warning(
            "PrizeBondPK listed bond numbers in multiple prize tiers; "
            "kept the highest tier (denomination=%s, date=%s, url=%s, "
            "duplicates=%s).",
            result["denomination"],
            result["draw_date"],
            result["url"],
            sorted(set(duplicate_numbers)),
        )

    missing_tiers = [
        name
        for index, name in enumerate(_PRIZE_TIER_NAMES)
        if index not in found_tiers
    ]
    if missing_tiers:
        error = f"Could not extract {', '.join(missing_tiers)} prize tiers"
    elif not any(prize_numbers):
        error = "No winning bond numbers were found."
    else:
        error = None

    return PrizeBondTextResult(
        denomination=int(result["denomination"]),
        draw_date=date.fromisoformat(result["draw_date"]),
        url=result["url"],
        first_prize_numbers=prize_numbers[0],
        second_prize_numbers=prize_numbers[1],
        third_prize_numbers=prize_numbers[2],
        error=error,
    )
