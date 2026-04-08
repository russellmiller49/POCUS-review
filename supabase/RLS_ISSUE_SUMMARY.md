# RLS Policy Violation Issue - Detailed Summary

## Problem Statement

**Error Message:** `"new row violates row-level security policy for table 'studies'"`

**When it occurs:** When attempting to create a new study in the iOS app

**User affected:** User ID: `db9d49e5-10bb-49d1-ae0d-63893b84e308`

---

## Root Cause Analysis

### The Issue

The Row Level Security (RLS) policy on the `studies` table is blocking study creation, even though the user has a valid, approved membership.

### Why It's Happening

1. **Membership exists and is approved:**
   - User has membership record: `user_id: db9d49e5-10bb-49d1-ae0d-63893b84e308`
   - Institution: `fd5043e9-9268-4b82-a703-88b18c8c0fd0`
   - Role: `fellow`
   - Status: `role_approved: true` ✅
   - PGY Year: `PGY-4`

2. **RLS helper functions don't check `role_approved`:**
   - The RLS policy uses helper functions: `is_member_of()` and `has_role()`
   - These functions check if a user is a member of an institution
   - **BUT** they don't verify that `role_approved = true`
   - So they might return `true` for pending/unapproved memberships

3. **The study insert policy:**
   ```sql
   CREATE POLICY "member inserts own studies"
   ON public.studies FOR INSERT
   WITH CHECK (
     created_by = auth.uid()
     AND public.is_member_of(institution_id)
   );
   ```
   - This policy requires `is_member_of()` to return `true`
   - Since `is_member_of()` doesn't check `role_approved`, it might fail incorrectly
   - OR it might pass for unapproved users (security issue)

---

## Technical Details

### Current RLS Helper Functions (BROKEN)

```sql
-- Current is_member_of() - DOESN'T CHECK role_approved
CREATE FUNCTION public.is_member_of(inst_id uuid)
RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.memberships m
    WHERE m.user_id = auth.uid()
      AND m.institution_id = inst_id
      -- MISSING: AND (m.role_approved = true OR m.role_approved IS NULL)
  );
$$;
```

**Problem:** This function returns `true` for ANY membership, even if `role_approved = false`

### What We Need (FIXED)

```sql
-- Fixed is_member_of() - CHECKS role_approved
CREATE FUNCTION public.is_member_of(inst_id uuid)
RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.memberships m
    WHERE m.user_id = auth.uid()
      AND m.institution_id = inst_id
      AND (m.role_approved = true OR m.role_approved IS NULL) -- ✅ FIXED
  );
$$;
```

---

## What We've Done So Far

### ✅ Completed Steps

1. **Identified the problem:** RLS policy violation when creating studies
2. **Verified membership exists:** User has approved membership record
3. **Created fix scripts:**
   - `fix_study_creation_rls.sql` - Updates all RLS helper functions
   - `fix_membership_for_user.sql` - Ensures membership is correct
   - `diagnose_rls_issue.sql` - Diagnostic queries
   - `verify_membership.sql` - Quick verification

4. **Ran membership fix:** Successfully ensured membership is set up correctly

### ⏳ Pending Steps

1. **Run the RLS fix script:** `fix_study_creation_rls.sql` needs to be executed in Supabase SQL Editor
2. **Test study creation:** After running the fix, test creating a study in the app

---

## Solution Steps

### Step 1: Run the RLS Fix Script

**File:** `supabase/fix_study_creation_rls.sql`

**Where to run:** Supabase Dashboard → SQL Editor

**What it does:**
- Updates `is_member_of()` to check `role_approved`
- Updates `has_role()` to check `role_approved`
- Updates `has_admin_role()` to check `role_approved`
- Updates `can_access_study()` to check `role_approved`
- Recreates the study insert policy

**Expected result:** "Success" messages for each function update

### Step 2: Verify the Fix

Run this test query in SQL Editor:

```sql
-- Test if the function now recognizes your approved membership
SELECT 
    public.is_member_of('fd5043e9-9268-4b82-a703-88b18c8c0fd0'::uuid) as is_member,
    public.has_role('fd5043e9-9268-4b82-a703-88b18c8c0fd0'::uuid, 'fellow') as has_fellow_role;
```

**Expected result:** Both should return `true`

### Step 3: Test in App

1. **Sign out** of the app (to refresh session)
2. **Sign back in**
3. **Try creating a study** - should work now!

---

## Files Created

### 1. `fix_study_creation_rls.sql`
**Purpose:** Main fix script that updates all RLS helper functions
**Status:** ✅ Ready to run
**Action needed:** Run in Supabase SQL Editor

### 2. `fix_membership_for_user.sql`
**Purpose:** Ensures membership is correctly set up for the user
**Status:** ✅ Already executed (showed "Success")
**Action needed:** None

### 3. `diagnose_rls_issue.sql`
**Purpose:** Diagnostic queries to identify the problem
**Status:** ✅ Created
**Action needed:** Run if issues persist after fix

### 4. `verify_membership.sql`
**Purpose:** Quick verification of membership status
**Status:** ✅ Created
**Action needed:** Run to verify membership exists

### 5. `create_my_membership.sql`
**Purpose:** Template for creating memberships
**Status:** ✅ Created
**Action needed:** Not needed (membership already exists)

---

## Database Schema Context

### Memberships Table Structure

```sql
CREATE TABLE public.memberships (
  user_id uuid NOT NULL,
  institution_id uuid NOT NULL,
  role text NOT NULL CHECK (role IN ('fellow', 'attending', 'admin')),
  roles text[],  -- Optional array for multiple roles
  role_approved boolean NOT NULL DEFAULT true,  -- ✅ NEW COLUMN
  pgy_year text CHECK (pgy_year IN ('PGY-4', 'PGY-5', 'PGY-6')),
  role_requested_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, institution_id)
);
```

### Studies Table RLS Policy

```sql
-- Current policy (after fix)
CREATE POLICY "member inserts own studies"
ON public.studies FOR INSERT
TO authenticated
WITH CHECK (
  created_by = auth.uid()
  AND public.is_member_of(institution_id)  -- Now checks role_approved ✅
);
```

---

## Why This Matters

### Security Implications

Without checking `role_approved`:
- Users with pending memberships (`role_approved = false`) could potentially create studies
- This violates the approval workflow we implemented for Attending/Admin roles

### User Experience

- Legitimate users (like you) with approved memberships can't create studies
- Error message is confusing: "row-level security policy violation"
- Users don't know why they can't create studies

---

## Migration History

### Related Migrations

1. `20251107000000_signup_enhancements.sql`
   - Added `role_approved` column to `memberships`
   - Added `pgy_year` column
   - Created approval workflow

2. `20251108094000_membership_role_helpers.sql`
   - Updated `has_role()` to check both `role` column and `roles` array
   - But didn't add `role_approved` check ❌

3. `20251108095500_relax_study_insert_policy.sql`
   - Relaxed study insert policy to just check membership
   - But didn't update `is_member_of()` to check `role_approved` ❌

4. `20251108100000_fix_rls_role_approval.sql` (pending)
   - Should fix all helper functions to check `role_approved`
   - Can't be pushed due to connection pool timeouts

---

## Current Status

### ✅ What's Working
- Membership record exists and is approved
- Database schema is correct
- Fix scripts are ready

### ❌ What's Broken
- RLS helper functions don't check `role_approved`
- Study creation is blocked by RLS policy
- Migration can't be pushed due to connection issues

### 🔧 What Needs to Happen
1. Run `fix_study_creation_rls.sql` in Supabase SQL Editor (bypasses migration system)
2. Test study creation in app
3. If successful, the migration `20251108100000_fix_rls_role_approval.sql` can be marked as applied later

---

## Troubleshooting

### If study creation still fails after running the fix:

1. **Check if functions were updated:**
   ```sql
   SELECT pg_get_functiondef('public.is_member_of'::regproc);
   ```
   Look for `role_approved = true` in the function body

2. **Check membership status:**
   ```sql
   SELECT * FROM public.memberships 
   WHERE user_id = 'db9d49e5-10bb-49d1-ae0d-63893b84e308'::uuid;
   ```
   Verify `role_approved = true`

3. **Test RLS functions directly:**
   ```sql
   SELECT 
     auth.uid() as current_user,
     public.is_member_of('fd5043e9-9268-4b82-a703-88b18c8c0fd0'::uuid) as is_member;
   ```

4. **Check if policy exists:**
   ```sql
   SELECT * FROM pg_policies 
   WHERE tablename = 'studies' AND policyname = 'member inserts own studies';
   ```

---

## Summary

**The Problem:** RLS helper functions don't check `role_approved`, causing study creation to fail even for approved users.

**The Solution:** Update all RLS helper functions to check `role_approved = true` (or NULL for backward compatibility).

**The Action:** Run `fix_study_creation_rls.sql` in Supabase SQL Editor, then test study creation in the app.

**Expected Outcome:** Study creation should work immediately after running the fix script.

---

## Next Steps

1. ✅ **DONE:** Membership verified and fixed
2. ⏳ **TODO:** Run `fix_study_creation_rls.sql` in Supabase SQL Editor
3. ⏳ **TODO:** Test study creation in app
4. ⏳ **TODO:** If successful, mark migration as applied

---

*Last updated: 2025-11-08*
*Issue ID: RLS-POLICY-VIOLATION-001*

