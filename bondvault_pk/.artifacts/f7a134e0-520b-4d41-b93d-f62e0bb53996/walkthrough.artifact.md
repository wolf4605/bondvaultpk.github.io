# Walkthrough - Contact Number Normalization, Register Fix & UI Alignment

Added automatic contact number normalization in `register_screen.dart` to ensure mobile numbers always start with `+92` as required by the backend validator.

## Changes Made

### [Contact Number Normalization (`lib/screens/register_screen.dart`)](file:///C:/Code/bondvaultpk.github.io/bondvault_pk/lib/screens/register_screen.dart)
- **Automatic `+92` Prefix Formatting**: Automatically checks and formats contact inputs (e.g. converting `03001234567` or `3001234567` to `+923001234567`) before submitting the registration payload, ensuring 100% compliance with backend Pydantic validation rules.
