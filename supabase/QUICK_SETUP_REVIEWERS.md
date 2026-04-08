# Quick Setup: TestFlight Reviewer Accounts

## ⚡ Fast Track (5 minutes)

### Step 1: Create Users (2 minutes)

1. Go to **Supabase Dashboard** → **Authentication** → **Users**
2. Click **"Add user"** three times with these details:

**User 1:**
- Email: `reviewer.fellow@testflight.app`
- Password: `TestFlight2024!`
- ✅ **Auto Confirm User** (MUST CHECK!)

**User 2:**
- Email: `reviewer.attending@testflight.app`
- Password: `TestFlight2024!`
- ✅ **Auto Confirm User** (MUST CHECK!)

**User 3:**
- Email: `reviewer.admin@testflight.app`
- Password: `TestFlight2024!`
- ✅ **Auto Confirm User** (MUST CHECK!)

### Step 2: Run Setup Script (1 minute)

1. Go to **SQL Editor**
2. Open `SETUP_TESTFLIGHT_ACCOUNTS.sql`
3. Copy all contents → Paste → Click **"Run"**

### Step 3: Verify (30 seconds)

1. Run `CHECK_REVIEWER_ACCOUNTS.sql` in SQL Editor
2. All three accounts should show **"✅ Ready"**

## ✅ Done!

Now test in the app:
1. Open app
2. Tap **"TestFlight Reviewer"**
3. Select a role → Should log in immediately!

