"""
* Project Name: BONDVAULT PK

* Description: 

* Author: Wolf4605
* Email: mab4605@gmail.com

* Date: 2026-10-23 10:59:03

* Last Modified by: Wolf4605
* Last Modified time: 2026-10-24 10:33:43

* License: MIT
* Copyright© BondVault PK. All rights reserved.
""""""Shared configuration for models loaded from database records."""

from pydantic import BaseModel, ConfigDict


class Model(BaseModel):
    """Common configuration for models created from records."""

    model_config = ConfigDict(from_attributes=True, extra="ignore")


__all__ = ["Model"]
