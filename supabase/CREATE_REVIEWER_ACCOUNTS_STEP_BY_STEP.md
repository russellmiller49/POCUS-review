# Step-by-Step: Create TestFlight Reviewer Accounts

## Step 1: Create Users in Supabase Dashboard

1. **Open Supabase Dashboard**
   - Go to: https://supabase.com/dashboard
   - Select your project

2. **Navigate to Authentication**
   - Click **"Authentication"** in the left sidebar
   - Click **"Users"** tab

3. **Create Account 1: Fellow**
   - Click **"Add user"** button (top right)
   - **Email**: `reviewer.fellow@testflight.app`
   - **Password**: `TestFlight2024!`
   - **Auto Confirm User**: ✅ **CHECK THIS BOX** (very important!)
   - Click **"Create user"**

4. **Create Account 2: Attending**
   - Click **"Add user"** again
   - **Email**: `reviewer.attending@testflight.app`
   - **Password**: `TestFlight2024!`
   - **Auto Confirm User**: ✅ **CHECK THIS BOX**
   - Click **"Create user"**

5. **Create Account 3: Admin**
   - Click **"Add user"** again
   - **Email**: `reviewer.admin@testflight.app`
   - **Password**: `TestFlight2024!`
   - **Auto Confirm User**: ✅ **CHECK THIS BOX**
   - Click **"Create user"**

## Step 2: Set Up Memberships and Profiles

1. **Go to SQL Editor**
   - Click **"SQL Editor"** in the left sidebar
   - Click **"New query"**

2. **Run the Setup Script**
   - Open `SETUP_TESTFLIGHT_ACCOUNTS.sql`
   - Copy the entire contents
   - Paste into the SQL Editor
   - Click **"Run"** (or press Cmd+Enter)

3. **Check the Output**
   - You should see notices like:
     - `✅ Fellow account configured`
     - `✅ Attending account configured`
     - `✅ Admin account configured`
   - The final query will show all three accounts with their status

## Step 3: Verify Everything Works

Run this verification query:

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

All three should show **"✅ Ready"**.

## Troubleshooting

### If accounts show "Missing Profile":
- The SQL script should have created them
- Try running `SETUP_TESTFLIGHT_ACCOUNTS.sql` again

### If accounts show "Not Approved":
- Run this to approve them:
```sql
UPDATE public.memberships
SET role_approved = true
WHERE user_id IN (
  SELECT id FROM auth.users WHERE email LIKE 'reviewer.%@testflight.app'
);
```

### If users don't exist:
- Make sure you created them in the Dashboard with "Auto Confirm User" checked
- Check the email addresses are exactly:
  - `reviewer.fellow@testflight.app`
  - `reviewer.attending@testflight.app`
  - `reviewer.admin@testflight.app`

