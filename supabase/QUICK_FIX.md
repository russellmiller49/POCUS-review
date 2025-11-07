# Quick Fix for `supabase db push` Connection Issues

## ✅ WORKING SOLUTION

Use the correct pooler hostname (`aws-1-us-west-1` for us-west-1 region):

```bash
cd /Users/russellmiller/Projects/POCUS_APP/POCUS_Mentor
supabase db push --yes --db-url "postgresql://postgres.tqnhxlwvkkswuckszlee:YOUR_PASSWORD@aws-1-us-west-1.pooler.supabase.com:6543/postgres?pgbouncer=true"
```

**Note:** Replace `YOUR_PASSWORD` with your actual database password.

## The Problem
- Connection pool exhaustion
- IPv6 DNS resolution failure for direct database hostname
- "Tenant or user not found" when using wrong pooler hostname (`aws-0-us-west-1`)

## Alternative Solution: Use Dashboard Connection String

### Step 1: Get Connection String
1. Open: https://supabase.com/dashboard/project/tqnhxlwvkkswuckszlee/settings/database
2. Scroll to **"Connection string"** section
3. Click on **"Connection pooling"** tab
4. Select **"Transaction mode"** (recommended for migrations)
5. Click the **copy button** next to the connection string

### Step 2: Use the Connection String
```bash
cd /Users/russellmiller/Projects/POCUS_APP/POCUS_Mentor
supabase db push --yes --db-url "PASTE_YOUR_CONNECTION_STRING_HERE"
```

**Important:** 
- Paste the ENTIRE connection string from the dashboard
- Don't modify it - use it exactly as copied
- The dashboard connection string is already properly formatted and URL-encoded

### Alternative: Use Password Flag (If Supported)
If you prefer to enter password interactively:
```bash
supabase db push --yes -p YOUR_DATABASE_PASSWORD
```

## Why This Works
- Dashboard connection strings are pre-configured and tested
- They're already URL-encoded for special characters
- They use the correct pooler endpoint that resolves via DNS
- They bypass the CLI's internal connection logic that's failing

## If Still Failing
1. **Check Dashboard** - Ensure project status is "ACTIVE_HEALTHY"
2. **Wait 5-10 minutes** - Connection pool might be temporarily exhausted
3. **Check Network Restrictions** - Dashboard > Settings > Database > Network Restrictions
4. **Use SQL Editor** - As last resort, run migrations manually via Dashboard SQL Editor

