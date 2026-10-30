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
from typing import Annotated

from fastapi import APIRouter, Depends, status
from starlette.exceptions import HTTPException

from src import payloads

from .. import models, responses
from ..database import DB
from ..utilities.auth_dependencies import get_current_user

router = APIRouter(
    prefix = "/bonds",
    tags= ["Prize Bonds"]
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