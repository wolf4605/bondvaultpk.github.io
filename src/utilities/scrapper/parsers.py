"""HTML and text parsing for prize bond draw results."""

import re
import unicodedata
from datetime import date, datetime
from pathlib import PurePosixPath
from urllib.parse import urljoin, urlsplit

from lxml import html

from .models import PrizeBondDrawResult

_DENOMINATION_PATTERN = re.compile(r"Rs\.?\s*([\d,]+)", re.IGNORECASE)
_RESULT_FILE_EXTENSIONS = {".csv", ".doc", ".docx", ".pdf", ".txt", ".xls", ".xlsx"}
_DRAW_DATE_PATTERN = re.compile(r"\b\d{1,2}[-/.]\d{1,2}[-/.]\d{4}\b")
_COMPACT_DRAW_DATE_PATTERN = re.compile(r"(?<!\d)\d{6}(?!\d)")
_PRIZE_TIER_PATTERN = re.compile(
    r"\b(?P<tier>first|second|third|1st|2nd|3rd)\s+"
    r"(?P<label>p{1,2}rize|price)s?\b",
    re.IGNORECASE,
)
_CURRENCY_AMOUNT_PATTERN = re.compile(
    r"(?:Rs\.?\s*)+[\d,]+(?:\s*/-?)?",
    re.IGNORECASE,
)
_WINNING_NUMBER_PATTERN = re.compile(r"(?<!\d)\d{3,6}(?!\d)")
_EXPECTED_PRIZE_NUMBER_COUNTS = {
    100: (1, 3),
    200: (1, 5),
    750: (1, 3),
    1500: (1, 3),
    25000: (2, 5),
    40000: (1, 3),
}


def _extract_drawlist_links(content: bytes, page_url: str) -> dict[int, str]:
    document = html.fromstring(content, base_url=page_url)
    drawlist_links: dict[int, str] = {}

    for anchor in document.xpath("//a[@href]"):
        label = " ".join(anchor.text_content().split())
        if (
            "prize bond" not in label.casefold()
            or "draw list" not in label.casefold()
        ):
            continue

        match = _DENOMINATION_PATTERN.search(label)
        if match is None:
            raise ValueError(
                f"Could not determine denomination from draw-list link: {label}"
            )

        denomination = int(match.group(1).replace(",", ""))
        drawlist_links[denomination] = urljoin(page_url, anchor.get("href"))

    if not drawlist_links:
        raise ValueError(f"No prize bond draw-list links found at {page_url}")

    return drawlist_links


def _parse_result_links(
    content: bytes,
    page_url: str,
) -> list[PrizeBondDrawResult]:
    document = html.fromstring(content, base_url=page_url)
    results = []

    for anchor in document.xpath("//article//a[@href]"):
        absolute_url = urljoin(page_url, anchor.get("href"))
        extension = PurePosixPath(urlsplit(absolute_url).path).suffix.casefold()
        if extension in _RESULT_FILE_EXTENSIONS:
            draw_date = _extract_draw_date(anchor)
            if draw_date is None:
                raise ValueError(
                    f"Could not determine draw date for result file: {absolute_url}"
                )
            results.append(
                PrizeBondDrawResult(
                    draw_date=draw_date,
                    url=absolute_url,
                    file_type=extension.removeprefix("."),
                )
            )

    return results


def _extract_draw_date(anchor: html.HtmlElement) -> date | None:
    anchor_text = " ".join(anchor.text_content().split())
    match = _DRAW_DATE_PATTERN.search(anchor_text)
    if match is not None:
        for date_format in ("%d-%m-%Y", "%d/%m/%Y", "%d.%m.%Y"):
            try:
                return datetime.strptime(match.group(), date_format).date()
            except ValueError:
                continue

    compact_match = _COMPACT_DRAW_DATE_PATTERN.search(anchor_text)
    if compact_match is not None:
        try:
            return datetime.strptime(compact_match.group(), "%d%m%y").date()
        except ValueError:
            pass

    return None


def _decode_text_file(content: bytes) -> str:
    try:
        return content.decode("utf-8-sig")
    except UnicodeDecodeError:
        if content.startswith((b"\xff\xfe", b"\xfe\xff")):
            return content.decode("utf-16")
        return content.decode("cp1252")


def _parse_prize_numbers(
    text: str,
    denomination: int,
) -> tuple[tuple[str, ...], tuple[str, ...], tuple[str, ...]]:
    try:
        expected_first, expected_second = _EXPECTED_PRIZE_NUMBER_COUNTS[denomination]
    except KeyError as error:
        raise ValueError(
            f"Unsupported prize bond denomination: {denomination}"
        ) from error

    prizes: dict[int, list[str]] = {1: [], 2: [], 3: []}
    active_tier: int | None = None

    for raw_line in unicodedata.normalize("NFKC", text).splitlines():
        line = raw_line.replace("\xa0", " ").strip()
        if not line:
            continue

        tier_match = _PRIZE_TIER_PATTERN.search(line)
        if tier_match and not _is_explanatory_prize_line(line):
            tier = _tier_number(tier_match.group("tier"))
            inline_numbers = _inline_winning_numbers(line, tier_match)
            if inline_numbers:
                _append_prize_numbers(
                    prizes[tier],
                    inline_numbers,
                    _expected_count(tier, expected_first, expected_second),
                )
                if tier == 2 and len(prizes[2]) >= expected_second:
                    active_tier = 3
                elif tier == 3:
                    active_tier = None
                else:
                    active_tier = None
            else:
                active_tier = tier
            continue

        if active_tier is None:
            continue

        numbers = _winning_numbers_from_row(line)
        if not numbers:
            continue

        expected_count = _expected_count(active_tier, expected_first, expected_second)
        _append_prize_numbers(prizes[active_tier], numbers, expected_count)
        if active_tier == 1 and len(prizes[1]) >= expected_first:
            active_tier = None
        elif active_tier == 2 and len(prizes[2]) >= expected_second:
            active_tier = 3

    return tuple(prizes[1]), tuple(prizes[2]), tuple(prizes[3])


def _tier_number(tier: str) -> int:
    return {"first": 1, "1st": 1, "second": 2, "2nd": 2, "third": 3, "3rd": 3}[
        tier.casefold()
    ]


def _expected_count(tier: int, first_count: int, second_count: int) -> int | None:
    if tier == 1:
        return first_count
    if tier == 2:
        return second_count
    return None


def _is_explanatory_prize_line(line: str) -> bool:
    return len(line) > 180 or bool(
        re.search(r"\b(?:declared|mentioned there|will get|similarly)\b", line, re.I)
    )


def _inline_winning_numbers(
    line: str,
    tier_match: re.Match[str],
) -> list[str]:
    prefix = line[: tier_match.start()]
    prefix_numbers = _winning_numbers_from_row(prefix)
    if prefix_numbers:
        return prefix_numbers

    suffix = _CURRENCY_AMOUNT_PATTERN.sub("", line[tier_match.end() :])
    return _winning_numbers_from_row(suffix)


def _winning_numbers_from_row(line: str) -> list[str]:
    cleaned = _CURRENCY_AMOUNT_PATTERN.sub("", line)
    cleaned = re.sub(r"(?:\bX{3,}\b|\*{3,})", " ", cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(
        r"^\s*\d{1,3}\s+prizes?\b[:\s]*",
        "",
        cleaned,
        flags=re.IGNORECASE,
    )
    cleaned = cleaned.strip(" \t\r\n\"'“”()[]{}:;,.|/-")
    if not cleaned:
        return []

    individual_digits = re.fullmatch(r"\d(?:\s+\d){5,}", cleaned)
    if individual_digits:
        digits = "".join(cleaned.split())
        if len(digits) % 6 == 0:
            return [digits[index : index + 6] for index in range(0, len(digits), 6)]

    if not re.fullmatch(r"\d{3,6}(?:[\s\t,;|/-]+\d{3,6})*", cleaned):
        return []
    return [
        number
        for number in _WINNING_NUMBER_PATTERN.findall(cleaned)
        if number != "000000"
    ]


def _append_prize_numbers(
    target: list[str],
    numbers: list[str],
    expected_count: int | None,
) -> None:
    if expected_count is not None:
        numbers = numbers[: max(0, expected_count - len(target))]
    target.extend(numbers)
