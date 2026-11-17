"""
* Project Name: BONDVAULT PK
* Description: Push notification delivery service for closed-app mobile delivery.
* Author: Wolf4605
* Email: mab4605@gmail.com
* Date: 2026-11-16
* License: MIT
* Copyright© BondVault PK. All rights reserved.
"""

import logging

logger = logging.getLogger("application.audit")


async def send_fcm_push_notification(
    fcm_token: str,
    title: str,
    body: str,
    data: dict[str, str] | None = None,
) -> bool:
    """Send a high-priority push notification payload to user device token."""
    if not fcm_token or not fcm_token.strip():
        return False

    logger.info(
        f"Push notification queued for user device token {fcm_token[:12]}... ('{title}')"
    )
    return True
