# TestFlight Reviewer Login Setup

This guide explains how to set up test accounts for App Store reviewers to test your app without email verification.

## Overview

The app now includes a "TestFlight Reviewer" login option that allows App Store reviewers to:
- Log in without email verification
- Test all three roles (Fellow, Attending, Admin)
- Access the full app functionality

## Step 1: Create Test Accounts in Supabase

1. Go to your Supabase Dashboard: **Authentication → Users**
2. Click **"Add user"** and create three test accounts:

### Account 1: Fellow
- **Email**: `reviewer.fellow@testflight.app`
- **Password**: `TestFlight2024!`
- **Auto Confirm User**: ✅ (checked)

### Account 2: Attending
- **Email**: `reviewer.attending@testflight.app`
- **Password**: `TestFlight2024!`
- **Auto Confirm User**: ✅ (checked)

### Account 3: Admin
- **Email**: `reviewer.admin@testflight.app`
- **Password**: `TestFlight2024!`
- **Auto Confirm User**: ✅ (checked)

**Important**: Make sure "Auto Confirm User" is checked so they don't need email verification!

## Step 2: Set Up Memberships and Profiles

1. Go to **SQL Editor** in Supabase Dashboard
2. Copy and paste the contents of `SETUP_TESTFLIGHT_ACCOUNTS.sql`
3. Run the script - it will:
   - Create a test institution
   - Create profiles for all three accounts
   - Create memberships with proper roles
   - Approve all roles automatically

## Step 3: Verify Setup

Run this query to verify everything is set up correctly:

```sql
SELECT
  u.email,
  p.full_name,
  i.name as institution,
  m.role,
  m.roles,
  m.role_approved,
  CASE
    WHEN p.id IS NULL THEN '❌ Missing Profile'
    WHEN COALESCE(m.role_approved, true) = false THEN '❌ Not Approved'
    ELSE '✅ Ready'
  END as status
FROM auth.users u
LEFT JOIN public.profiles p ON p.id = u.id
LEFT JOIN public.memberships m ON m.user_id = u.id
LEFT JOIN public.institutions i ON i.id = m.institution_id
WHERE u.email LIKE 'reviewer.%@testflight.app'
ORDER BY u.email;
```

All three accounts should show "✅ Ready".

## Step 4: Test in the App

1. Open the app
2. On the login screen, tap **"TestFlight Reviewer"**
3. Select a role (Fellow, Attending, or Admin)
4. You should be logged in immediately without email verification

## For App Store Reviewers

When submitting to TestFlight, include these instructions in your **App Review Information**:

> **TestFlight Reviewer Login Instructions:**
> 
> To test the app without email verification:
> 1. Tap "TestFlight Reviewer" on the login screen
> 2. Select a role to test:
>    - **Fellow**: Create and submit studies
>    - **Attending**: Review and provide feedback on studies
>    - **Admin**: View program analytics and manage users
> 
> All test accounts are pre-configured and ready to use.

## Security Notes

- These accounts are only for TestFlight review
- The passwords are intentionally simple for reviewers
- Consider disabling these accounts after App Store approval
- The accounts use a separate test institution

## Disabling After Approval

After your app is approved, you can disable these accounts:

```sql
-- Disable reviewer accounts (optional)
UPDATE auth.users
SET banned_until = '2099-12-31'::timestamp
WHERE email LIKE 'reviewer.%@testflight.app';
```

Or simply remove them from Supabase Dashboard.

