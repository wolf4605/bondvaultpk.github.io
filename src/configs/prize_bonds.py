"""
* Project Name: BONDVAULT PK

* Description: Contains some configs regarding Pakistani Prize Bonds.

* Author: Wolf4605
* Email: mab4605@gmail.com

* Date: 2026-10-22 19:32:18

* Last Modified by: Wolf4605
* Last Modified time: 2026-10-22 19:32:19

* License: MIT
* Copyright© BondVault PK. All rights reserved.
"""

from enum import IntEnum


PRIZE_POSITION_NAMES = {
    1: "1st Prize",
    2: "2nd Prize",
    3: "3rd Prize",
}


class PrizeBondDenominations(IntEnum):
    """Denominations for the Pakistani Prize Bonds."""

    Rs_100 = 100
    Rs_200 = 200
    Rs_750 = 750
    Rs_1500 = 1500
    Rs_25000 = 25000
    Rs_40000 = 40000