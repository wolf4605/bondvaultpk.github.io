"""
* Project Name: BONDVAULT PK

* Description: 

* Author: Wolf4605
* Email: mab4605@gmail.com

* Date: 2026-10-23 19:09:05

* Last Modified by: Wolf4605
* Last Modified time: 2026-10-23 19:09:26

* License: MIT
* Copyright© BondVault PK. All rights reserved.
"""

from collections.abc import Mapping
from typing import Annotated, Any

from fastapi import APIRouter, Depends, Path, Query, status
from starlette.exceptions import HTTPException

from src import payloads

from .. import models, responses
from ..configs import PRIZE_POSITION_NAMES, PrizeBondDenominations
from ..database import DB
from ..utilities.auth_dependencies import get_current_user

router = APIRouter(
    prefix = "/bonds",
    tags= ["Prize Bonds"]
)

def _normalize_bond_number(bond_number: str) -> str:
    """Pad a one-to-six digit bond number to its six-digit stored form."""
    normalized_number = bond_number.zfill(6)
    if normalized_number == "000000":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Prize bond numbers must be between 000001 and 999999.",
        )
    return normalized_number


def _build_prize_bond_draw_match(
    record: Mapping[str, Any],
) -> responses.PrizeBondDrawMatch:
    """Convert a database winner row into its public response model."""
    prize_position = record["prize_position"]
    return responses.PrizeBondDrawMatch(
        bond_number=record["bond_number"],
        denomination=record["denomination"],
        prize_position=prize_position,
        prize_name=PRIZE_POSITION_NAMES[prize_position],
        prize_amount=record["prize_amount"],
        draw_date=record["draw_date"],
    )


@router.get(
    path="/draw-results/{denomination}/number/{bond_number}",
    response_model=responses.PrizeBondSearchResponse,
    summary="Search a prize-bond number in draw results",
    description="Search all draw results for a bond number in the selected denomination. This endpoint is public.",
)
async def search_draw_results_by_number(
    denomination: PrizeBondDenominations,
    bond_number: str = Path(
        pattern=r"^[0-9]{1,6}$",
        description="Bond number containing one to six digits; shorter numbers are zero-padded.",
    ),
) -> responses.PrizeBondSearchResponse:
    """Find every draw in which a bond number won a prize."""
    normalized_number = _normalize_bond_number(bond_number)
    records = await DB.fetch(
        """
        SELECT
            w."bond_number",
            d."denomination",
            w."prize_position",
            w."prize_amount",
            d."draw_date"
        FROM "draw_winners" AS w
        JOIN "drawlists" AS d ON d."draw_id" = w."draw_id"
        WHERE d."denomination" = $1
          AND w."bond_number" = $2
        ORDER BY d."draw_date" DESC
        """,
        denomination,
        normalized_number,
    )
    results = [_build_prize_bond_draw_match(record) for record in records]
    return responses.PrizeBondSearchResponse(
        results=results,
        total=len(results),
    )


@router.get(
    path="/draw-results/{denomination}/range",
    response_model=responses.PrizeBondSearchResponse,
    summary="Search a prize-bond number range in draw results",
    description="Find winning bonds in an inclusive number range and denomination across all draw dates. This endpoint is public.",
)
async def search_draw_results_by_range(
    denomination: PrizeBondDenominations,
    start_num: str = Query(
        pattern=r"^[0-9]{1,6}$",
        description="First bond number, inclusive; shorter numbers are zero-padded.",
    ),
    end_num: str = Query(
        pattern=r"^[0-9]{1,6}$",
        description="Last bond number, inclusive; shorter numbers are zero-padded.",
    ),
) -> responses.PrizeBondSearchResponse:
    """Find winning bonds in an inclusive range across all draw dates."""
    normalized_start = _normalize_bond_number(start_num)
    normalized_end = _normalize_bond_number(end_num)
    if normalized_start > normalized_end:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Start number cannot be greater than end number.",
        )

    records = await DB.fetch(
        """
        SELECT
            w."bond_number",
            d."denomination",
            w."prize_position",
            w."prize_amount",
            d."draw_date"
        FROM "draw_winners" AS w
        JOIN "drawlists" AS d ON d."draw_id" = w."draw_id"
        WHERE d."denomination" = $1
          AND w."bond_number" BETWEEN $2 AND $3
        ORDER BY d."draw_date" DESC, w."bond_number" ASC
        """,
        denomination,
        normalized_start,
        normalized_end,
    )
    results = [_build_prize_bond_draw_match(record) for record in records]
    return responses.PrizeBondSearchResponse(
        results=results,
        total=len(results),
    )


@router.get(
        path = "/bondlists",
        summary = "Fetch user's bondlist(s).",
        response_model = responses.UserBondlistGet,
        description="This endpoint fetches a the bondlist(s) of the user"
)
async def get_bondlists(
    user_info: Annotated[models.UserInfo, Depends(get_current_user)]
):
    """Fethces all the bondlists of the attached user."""

    query = """
        SELECT * FROM "bondlists"
        WHERE user_id = $1
    """
    records = await DB.fetch(query, user_info.id)
    bondlists_found:list[models.BondListBasic] = []

    for record in records:
        bondlists_found.append(models.BondListBasic(
            id = record["id"],
            denomination= record["denomination"],
            user_id= record["user_id"]
        ))


    return responses.UserBondlistGet(
        id = user_info.id,
        username= user_info.username,
        bondlists = models.BondListsBasic(
            bondlists=bondlists_found
        )
    )


@router.get(
        path = "/bondlists_ext",
        summary = "Fetch user's bondlist(s) with bonds",
        response_model = responses.UserBondlistGet,
        description= "This endpoint fetches a the detailed bondlist of the user with info regarding the bonds in that list."
)
async def get_bondlists_ext(
    user_info: Annotated[models.UserInfo, Depends(get_current_user)]
):

    query = """
        SELECT * FROM "bondlists"
        WHERE "user_id" = $1
    """

    records = await DB.fetch(query, user_info.id)
    bondlists_found:list[models.BondListExtended] = []

    for record in records:

        query = """
            SELECT "bond_number" FROM "bonds"
            WHERE "bondlist_id" = $1
        """
        bonds = await DB.fetch(query, record["id"])
        found_bonds = []
        if bonds:
            found_bonds = [x["bond_number"] for x in bonds]

        bondlists_found.append(
            models.BondListExtended(
                id = record["id"],
                user_id = record["user_id"],
                denomination= record["denomination"],
                bonds= found_bonds
            )
        )
    
    return responses.UserBondlistGet(
            id = user_info.id,
            username= user_info.username,
            bondlists = models.BondListsExtended(
                bondlists=bondlists_found
            )
        )
        
@router.post(
    path = "/range",
    response_model= responses.BaseResponse,
    summary="Add prize bonds by number range",
    response_description="The number of prize bonds added."
)
async def user_add_bonds_by_range(
    user: Annotated[models.UserInfo, Depends(get_current_user)],
    payload: payloads.AddBondsByRange
) -> responses.BaseResponse:
    """
    Add every prize bond in an inclusive numeric range.
    """
    # Validate that both inputs contain only digits
    if not payload.start_num.isdigit() or not payload.end_num.isdigit():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Start and end numbers must contain only digits."
        )

    start_int = int(payload.start_num)
    end_int = int(payload.end_num)

    if not (1 <= start_int <= 999999) or not (1 <= end_int <= 999999):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Prize bond numbers must be between 000001 and 999999."
        )
    
    if start_int > end_int:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Start number cannot be greater than end number."
            )

    # All prize bond numbers must be exactly 6 digits
    padding_length = 6

    # Fetching the users bondlist
    bondlist_id= await DB.fetchval( 
        """SELECT "id" FROM "bondlists" WHERE user_id = $1 AND denomination = $2""",
        user.id,
        payload.denomination
    )
    async with DB.transaction() as conn:
        if not bondlist_id:
            bondlist_id =await conn.fetchval(
                """
                INSERT INTO "bondlists" ("denomination", "user_id")
                VALUES ($1, $2)
                RETURNING "id"
                """, 
                payload.denomination, user.id
                    )

        result = await conn.execute(
            """
            INSERT INTO "bonds" ("bondlist_id", "bond_number")
            SELECT $1, lpad(series_num::text, $4, '0')
            FROM generate_series($2::integer, $3::integer) AS series_num
            """,
            bondlist_id,
            start_int,
            end_int,
            padding_length
        )

        parsed_added_count = int(result.split()[-1])

    return responses.BaseResponse(
        message = f"Successfully added for {parsed_added_count} Prize Bonds from the database against user: {user.id}."
    )

@router.delete(
    path = "/range",
    response_model=responses.BaseResponse,
    summary="Remove prize bonds by number range",
    response_description="The number of prize bonds removed.",
)
async def user_delete_bond_by_range(
    user: Annotated[models.UserInfo, Depends(get_current_user)],
    payload: payloads.AddBondsByRange
):
    """
    Remove every bond in an inclusive numeric range from a user's list.
    """
    # Validate that both inputs contain only digits
    if not payload.start_num.isdigit() or not payload.end_num.isdigit():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Start and end numbers must contain only digits."
        )

    # Validate the prize bond number range
    start_int = int(payload.start_num)
    end_int = int(payload.end_num)

    if not (1 <= start_int <= 999999) or not (1 <= end_int <= 999999):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Prize bond numbers must be between 000001 and 999999."
        )

    if start_int > end_int:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Start number cannot be greater than end number."
        )

    # All prize bond numbers must be exactly 6 digits
    padding_length = 6
    # Fetching the users bondlist
    bondlist_id = await DB.fetchval( 
        """SELECT "id" FROM "bondlists" WHERE user_id = $1 AND denomination = $2""",
        user.id,
        payload.denomination
    )
    if not bondlist_id:
        return HTTPException(status_code=status.HTTP_404_NOT_FOUND,
                             detail=f"No bondlist found against the {payload.denomination} for the user.")

    async with DB.transaction() as conn:
    
            result = await conn.execute(
                """
                DELETE FROM "bonds"
                WHERE "bondlist_id" = $1
                  AND "bond_number" IN (
                      SELECT lpad(series_num::text, $4, '0')
                      FROM generate_series($2::integer, $3::integer) AS series_num
                  )
                """, 
                bondlist_id, start_int, end_int, padding_length
            )
    
            parsed_deleted_count = int(result.split()[-1])
    
    return responses.BaseResponse(
        message = f"Successfully deleted for {parsed_deleted_count} Prize Bonds from the database against user: {user.id}."
    )

@router.post(
    path = "",
    response_model=responses.BaseResponse,
    summary="Add prize bonds",
    response_description="Confirmation that the submitted bonds were added.",
)
async def add_bonds(
    user: Annotated[models.UserInfo, Depends(get_current_user)],
    payload: payloads.BondAddPayload
):

    bondlist_id = await DB.fetchval("""
                SELECT "id" from "bondlists"
                WHERE
                    "user_id" = $1
                    AND
                    "denomination" = $2    
                """,
                user.id,
                payload.denomination)

    async with DB.transaction() as conn:

        if not bondlist_id:
            bondlist_id = await conn.fetchval("""
                INSERT INTO "bondlists"
                ("denomination", "user_id")
                VALUES
                ($1, $2)
                RETURNING "id"
            """,
            payload.denomination,
            user.id
            )

        await conn.execute("""
                INSERT INTO "bonds"
                ("bondlist_id", "bond_number")
                SELECT
                $1, unnest($2::VARCHAR[])
                ON CONFLICT ("bondlist_id", "bond_number") DO NOTHING
            """,
            bondlist_id,
            payload.bonds
            )
    return responses.BaseResponse(
            message = f"Successfully added {len(payload.bonds)} Prize Bonds to the database against user: {user.id}."
        )

@router.delete(
    path = "",
    response_model= responses.BaseResponse,
    summary = "Remove Prize Bonds",
    response_description="Confirmation that the submitted bonds were removed.",
)
async def delete_bonds(
user: Annotated[models.UserInfo, Depends(get_current_user)],
payload: payloads.BondAddPayload
):
    """Removes the bonds from the user's bondlist."""

    bondlist_id = await DB.fetchval( 
            """
            SELECT "id"
            FROM "bondlists"
            WHERE
                user_id = $1
                AND
                denomination = $2
        """,
            user.id,
            payload.denomination
        )
    if not bondlist_id:
        return HTTPException(status_code=status.HTTP_404_NOT_FOUND,
                                detail=f"No bondlist found against the {payload.denomination} for the user.")

    async with DB.transaction() as conn:
        await conn.execute(
            """
            DELETE FROM "bonds"
            WHERE
                ("bondlist_id", "bond_number")
            IN 
                (SELECT $1::uuid, unnest($2::VARCHAR[]))
            """, 
            bondlist_id, payload.bonds
        )

    return responses.BaseResponse(
        message = f"Successfully deleted {len(payload.bonds)} Prize Bonds from the database against user: {user.id}."
    )