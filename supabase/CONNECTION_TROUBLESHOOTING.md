# Supabase Connection Troubleshooting Guide

## Current Issue
The `supabase db push` command is failing due to:
1. **Connection pool exhaustion** - The pooler is dropping requests after 10s timeout
2. **DNS resolution failure** - Direct database hostname `db.tqnhxlwvkkswuckszlee.supabase.co` doesn't resolve

## Solutions

### Option 1: Use Connection String from Dashboard (Recommended)

**IMPORTANT:** The connection string must be URL-encoded if your password contains special characters.

1. Go to: https://supabase.com/dashboard/project/tqnhxlwvkkswuckszlee/settings/database
2. Scroll to "Connection string" section
3. Select "Connection pooling" tab
4. Copy the "Session mode" or "Transaction mode" connection string
5. Use it directly:

```bash
# Example (replace with your actual connection string from dashboard):
# NOTE: For us-west-1 region, use aws-1-us-west-1 (not aws-0-us-west-1)
supabase db push --yes --db-url "postgresql://postgres.tqnhxlwvkkswuckszlee:[YOUR-PASSWORD]@aws-1-us-west-1.pooler.supabase.com:6543/postgres?pgbouncer=true"
```

**If your password has special characters**, URL-encode them:
- `@` becomes `%40`
- `#` becomes `%23`
- `$` becomes `%24`
- `%` becomes `%25`
- `&` becomes `%26`
- `+` becomes `%2B`
- `=` becomes `%3D`
- `?` becomes `%3F`
- `/` becomes `%2F`
- ` ` (space) becomes `%20`

Or use an online URL encoder: https://www.urlencoder.org/

### Option 2: Wait and Retry

The connection pool might be temporarily exhausted. Try:
1. Wait 5-10 minutes
2. Check Supabase Dashboard for active connections
3. Retry: `supabase db push --yes`

### Option 3: Check Supabase Dashboard

1. Go to: https://supabase.com/dashboard/project/tqnhxlwvkkswuckszlee/settings/database
2. Check "Connection Pooling" section
3. Look for any active connections that might be blocking
4. Check if there are any network restrictions enabled

### Option 4: Use Direct Connection (If Available)

If direct connections are enabled in your project settings:

```bash
# Get connection string from Dashboard > Settings > Database > Connection string
# Use the "Direct connection" (not pooler) option
# Copy the entire connection string from the dashboard
supabase db push --yes --db-url "YOUR_DIRECT_CONNECTION_STRING"
```

**Note:** Direct connections might have DNS resolution issues. If you get "no route to host" errors, stick with the pooler connection string.

### Option 5: Check Network Restrictions

Your project might have network restrictions enabled. Check:
- Dashboard > Settings > Database > Network Restrictions
- Ensure your IP is allowed or restrictions are disabled for CLI access

### Option 6: Use Supabase Dashboard SQL Editor

As a workaround, you can:
1. Go to Dashboard > SQL Editor
2. Manually run migrations from `supabase/migrations/` directory
3. This bypasses the CLI connection issues

## Debugging Commands

```bash
# Check project status
supabase projects list --output json

# Test DNS resolution
nslookup db.tqnhxlwvkkswuckszlee.supabase.co
nslookup aws-0-us-west-1.pooler.supabase.com

# Try with debug output
supabase db push --yes --debug

# Try different DNS resolver
supabase db push --yes --dns-resolver https
```

## Common Causes

1. **Too many active connections** - Other apps/services holding connections
2. **Network restrictions** - IP whitelist blocking CLI access
3. **Temporary Supabase service issues** - Check status.supabase.com
4. **IPv6 connectivity issues** - Your network might not support IPv6 properly
5. **"Tenant or user not found" error** - Usually means:
   - Wrong password in connection string
   - Password not URL-encoded (special characters need encoding)
   - Wrong connection string format
   - **Solution:** Copy the exact connection string from Dashboard, don't construct it manually

## Next Steps

1. **Immediate**: Try Option 1 with your database password
2. **Short-term**: Check Dashboard for connection issues
3. **Long-term**: Consider upgrading Supabase plan if pool exhaustion is frequent

