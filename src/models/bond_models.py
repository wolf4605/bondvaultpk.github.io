"""
* Project Name: BONDVAULT PK

* Description: Models for the bondlists and bonds.

* Author: Wolf4605
* Email: mab4605@gmail.com

* Date: 2026-10-24 10:32:57

* Last Modified by: Wolf4605
* Last Modified time: 2026-10-24 10:32:59

* License: MIT
* Copyright© BondVault PK. All rights reserved.
"""


from uuid import UUID

from pydantic import Field, field_validator

from ..configs import PrizeBondDenominations
from .base_model import Model


class BondListBasic(Model):
    """Contains Basic info regarding a Bondlist."""
    id: UUID = Field(default=..., description="The bondlist's unique identifier.")
    user_id: UUID = Field(default=..., description="The id of the user to whom the bondlist belongs.")
    denomination: PrizeBondDenominations = Field(default=..., description=" THe denomination of the prize bonds in the list.")


class BondListExtended(BondListBasic):
    """Shows the detailed info regarding a bondlist."""
    bonds:list[str]|str = Field(default=[], description= "The list of the prize bond(s)")
    
    @field_validator("bonds")
    @classmethod
    def convert_bonds(cls, x:list[str]|str) -> list[str]:
        """Converts the a single bond to list if passed as str."""

        if isinstance(x, str):
            return [x]
        return x

class BondListsGeneric[T: BondListBasic](Model):
    """Contains the shared structure for bondlists."""
    bondlists: list[T] = Field(
        default=[], 
        description="A list of bondlists of the user. Sends an empty list if no lists are found."
    )

class BondListsBasic(BondListsGeneric[BondListBasic]):
    """Contains only the basic info regarding the bondlists."""

class BondListsExtended(BondListsGeneric[BondListExtended]):
    """An extended model for the bondlists showing the bonds in the list too."""


__all__ = [
    "BondListBasic",
    "BondListExtended",
    "BondListsBasic",
    "BondListsExtended"
]