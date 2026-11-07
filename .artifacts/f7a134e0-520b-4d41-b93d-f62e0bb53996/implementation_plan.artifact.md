# Implementation Plan - User Signup Enhancements & Application Password Settings

Enhance user sign up validation (username, email, contact), add confirm password and app PIN fields, and create an application password management feature in the settings screen.

## User Review Required

> [!IMPORTANT]
> - **Signup Validation & Availability**: Dynamic checks will validate format/disallowed characters for username, email, and contact, and check availability against the database (or handling backend response errors for taken/blacklisted credentials).
> - **App PIN Feature**: Optional app PIN (4-6 digits) with confirmation during signup. If left blank, no PIN is set.
> - **Settings Screen**: New options in the Settings tab/screen to set, edit, or remove the application password / PIN.

## Proposed Changes

### [Flutter App (`bondvault_pk`)]

#### [MODIFY] [RegisterScreen](file:///C:/Code/bondvaultpk.github.io/bondvault_pk/lib/screens/register_screen.dart)
- Add controllers and validation logic for:
  - Username: valid characters only (no spaces or special symbols), check availability / blacklist.
  - Email: format check + availability / blacklist check.
  - Contact: phone format check + availability / blacklist check.
  - Confirm Password: match validation with Password.
  - App PIN & Confirm PIN: optional 4-6 digit PIN fields with matching confirmation.
- Save app PIN in `SharedPreferences` if provided upon registration.

#### [MODIFY] [HomeScreen / SettingsTab](file:///C:/Code/bondvaultpk.github.io/bondvault_pk/lib/screens/home_screen.dart)
- Enhance `_SettingsTab` to include Application Password / PIN management options:
  - Set Application Password / PIN
  - Edit Application Password / PIN
  - Remove Application Password / PIN

## Verification Plan

### Automated Tests
- Run `flutter test` (if applicable) and test project compilation.

### Manual Verification
- Test user registration with invalid characters, duplicate username/email/contact, mismatched passwords, and mismatched PINs.
- Test successful registration with and without an app PIN.
- Test Settings screen actions to set, edit, and remove application password / PIN.
