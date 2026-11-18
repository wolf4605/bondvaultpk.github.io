"""Password hashing and verification utilities."""

import argon2
from argon2 import PasswordHasher

_Password_Hasher: PasswordHasher = PasswordHasher()

def hash_password(password: str) -> str:
    """Hash a password using Argon2 Algorithm."""
    return _Password_Hasher.hash(password)


def verify_password(password: str, hash: str) -> bool:
    """Verify a password against a hashed password."""
    try:
        return _Password_Hasher.verify(hash, password)
    except (
        argon2.exceptions.InvalidHashError,
        argon2.exceptions.VerificationError,
    ):
        return False
