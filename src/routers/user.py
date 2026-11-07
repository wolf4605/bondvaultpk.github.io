"""
* Project Name: BONDVAULT PK

* Description: 

* Author: Wolf4605
* Email: mab4605@gmail.com

* Date: 2026-10-30 08:02:01

* Last Modified by: Wolf4605
* Last Modified time: 2026-10-30 08:02:02

* License: MIT
* Copyright© BondVault PK. All rights reserved.
"""

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, status
from starlette.exceptions import HTTPException

from .. import models, payloads, responses
from ..configs import PRIZE_POSITION_NAMES
from ..database import DB
from ..utilities.auth_dependencies import get_current_user

router = APIRouter(
    prefix="/user",
    tags= ["Users"]
)

MARKET_LISTING_UPDATE_FIELDS = {
    "title",
    "description",
    "price",
    "category",
}


@router.get(
    path = "",
    response_model=responses.UserInfoResponse,
    response_description="The profile info of the logged in user.",
    summary="Get User Profile"
)
async def _get_profile(user:Annotated[models.UserInfo, Depends(get_current_user)]) -> responses.UserInfoResponse:
    """Fetch the Users Profile Info From the DB."""
    return responses.UserInfoResponse(
        message = "OK",
        user_info = user
    )


@router.get(
    path="/bond-winnings",
    response_model=responses.PrizeBondSearchResponse,
    summary="Search the user's saved bonds in draw results",
)
async def get_user_bond_winnings(
    user: Annotated[models.UserInfo, Depends(get_current_user)],
) -> responses.PrizeBondSearchResponse:
    """Return all draw wins matching bonds saved in the authenticated user's lists."""
    records = await DB.fetch(
        """
        SELECT
            w."bond_number",
            d."denomination",
            w."prize_position",
            w."prize_amount",
            d."draw_date"
        FROM "bondlists" AS bl
        JOIN "bonds" AS b ON b."bondlist_id" = bl."id"
        JOIN "drawlists" AS d ON d."denomination" = bl."denomination"
        JOIN "draw_winners" AS w
          ON w."draw_id" = d."draw_id"
         AND char_length(b."bond_number") BETWEEN 1 AND 6
         AND w."bond_number" = lpad(b."bond_number", 6, '0')
        WHERE bl."user_id" = $1
        ORDER BY d."draw_date" DESC, d."denomination", w."bond_number"
        """,
        user.id,
    )
    results = [
        responses.PrizeBondDrawMatch(
            bond_number=record["bond_number"],
            denomination=record["denomination"],
            prize_position=record["prize_position"],
            prize_name=PRIZE_POSITION_NAMES[record["prize_position"]],
            prize_amount=record["prize_amount"],
            draw_date=record["draw_date"],
        )
        for record in records
    ]
    return responses.PrizeBondSearchResponse(results=results, total=len(results))


@router.patch(
    path="",
    summary="Update User Info",
    response_model=responses.BaseResponse
)
async def _update_user_info(
    user: Annotated[models.UserInfo, Depends(get_current_user)],
    payload: payloads.UserInfoUpdate,
):

    ALLOWED_UPDATE_FIELDS = {
        "username",
        "email",
        "first_name",
        "last_name",
        "contact",
        "city",
        "address",
        }

    raw_updates = payload.model_dump(exclude_unset=True, exclude_none=True)


    fields_to_update = {}
    for field, new_value in raw_updates.items():
        if field in ALLOWED_UPDATE_FIELDS and getattr(user, field, None) != new_value:
            fields_to_update[field] = new_value
    if not fields_to_update:
        raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail="No valid or changed fields were provided for update.",
        )
    set_clause = [
        f"{field} = ${i}"
        for i, field in enumerate(fields_to_update.keys(), start=2)
        ]
    query = (
        f"UPDATE users SET {', '.join(set_clause)} WHERE id = $1 RETURNING *"
        )
    values = [user.id] + list(fields_to_update.values())

    await DB.execute(query, *values)
    updated_fields_list = list(fields_to_update.keys())
   
    return responses.BaseResponse(
    message=f"Successfully updated fields: {', '.join(updated_fields_list)}"
    )


@router.post(
    path="/market/listings",
    response_model=responses.MarketListingInfo,
    status_code=status.HTTP_201_CREATED,
    summary="Create a marketplace listing",
)
async def create_market_listing(
    user: Annotated[models.UserInfo, Depends(get_current_user)],
    payload: payloads.MarketListingCreate,
) -> responses.MarketListingInfo:
    """Create a marketplace listing owned by the authenticated user."""
    record = await DB.fetchrow(
        """
        INSERT INTO "market" (
            "posted_by", "title", "description", "price", "category"
        )
        VALUES ($1, $2, $3, $4, $5)
        RETURNING
            "id", "posted_by", "title", "description", "price",
            "category", "created_at"
        """,
        user.id,
        payload.title,
        payload.description,
        payload.price,
        payload.category,
    )
    if record is None:
        raise RuntimeError("The marketplace listing could not be created.")
    return responses.MarketListingInfo(**record)


@router.patch(
    path="/market/listings/{listing_id}",
    response_model=responses.MarketListingInfo,
    summary="Update a marketplace listing",
)
async def update_market_listing(
    listing_id: UUID,
    user: Annotated[models.UserInfo, Depends(get_current_user)],
    payload: payloads.MarketListingUpdate,
) -> responses.MarketListingInfo:
    """Update a listing only when it belongs to the authenticated user."""
    updates = payload.model_dump(exclude_unset=True)
    if not updates:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="At least one listing field must be provided.",
        )

    set_clause = [
        f'"{field}" = ${index}'
        for index, field in enumerate(updates, start=3)
        if field in MARKET_LISTING_UPDATE_FIELDS
    ]
    record = await DB.fetchrow(
        f"""
        UPDATE "market"
        SET {", ".join(set_clause)}
        WHERE "id" = $1 AND "posted_by" = $2
        RETURNING
            "id", "posted_by", "title", "description", "price",
            "category", "created_at"
        """,
        listing_id,
        user.id,
        *updates.values(),
    )
    if record is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Marketplace listing not found.",
        )
    return responses.MarketListingInfo(**record)


@router.delete(
    path="/market/listings/{listing_id}",
    response_model=responses.BaseResponse,
    summary="Delete a marketplace listing",
)
async def delete_market_listing(
    listing_id: UUID,
    user: Annotated[models.UserInfo, Depends(get_current_user)],
) -> responses.BaseResponse:
    """Delete a listing only when it belongs to the authenticated user."""
    deleted_id = await DB.fetchval(
        """
        DELETE FROM "market"
        WHERE "id" = $1 AND "posted_by" = $2
        RETURNING "id"
        """,
        listing_id,
        user.id,
    )
    if deleted_id is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Marketplace listing not found.",
        )
    return responses.BaseResponse(message="Marketplace listing deleted.")