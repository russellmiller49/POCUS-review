# How to Relink Supabase CLI After Password Change

## Method 1: Interactive Link (Recommended)

Run this command and enter your password when prompted:

```bash
cd /Users/russellmiller/Projects/POCUS_APP/POCUS_Mentor
supabase link --project-ref tqnhxlwvkkswuckszlee
```

When prompted, enter your **new database password**.

## Method 2: Provide Password Directly

If you want to provide the password in the command:

```bash
cd /Users/russellmiller/Projects/POCUS_APP/POCUS_Mentor
supabase link --project-ref tqnhxlwvkkswuckszlee --password "YOUR_NEW_PASSWORD"
```

**Note:** Replace `YOUR_NEW_PASSWORD` with your actual password.

## Method 3: Skip Connection Pooler (If having connection issues)

If you're experiencing connection pool timeouts, try using direct connection:

```bash
cd /Users/russellmiller/Projects/POCUS_APP/POCUS_Mentor
supabase link --project-ref tqnhxlwvkkswuckszlee --skip-pooler
```

Then enter your password when prompted.

## Method 4: Use Direct Database Connection String

If the above methods don't work, you can manually update the connection in the config:

1. Get your database connection string from Supabase Dashboard:
   - Go to: Settings → Database
   - Copy the "Connection string" (use "Direct connection" not "Connection pooling")

2. The connection string format is:
   ```
   postgresql://postgres.[PROJECT_REF]:[PASSWORD]@aws-0-[REGION].pooler.supabase.com:6543/postgres
   ```

## Verify the Link

After linking, verify it worked:

```bash
supabase projects list
```

Or test a simple command:

```bash
supabase db pull --dry-run
```

## Troubleshooting

### Connection Pool Timeout

If you see connection pool timeout errors:
- Try Method 3 (--skip-pooler)
- Wait a few minutes and try again (pooler might be overloaded)
- Check Supabase Dashboard to ensure database is running

### Authentication Failed

If you see authentication errors:
- Double-check your password (copy/paste to avoid typos)
- Make sure you're using the **database password**, not your Supabase account password
- Reset the password in Dashboard if needed: Settings → Database → Reset Database Password

### Still Having Issues?

1. Check Supabase Dashboard → Settings → Database
2. Verify the project is active and not paused
3. Try linking from a different network (in case of firewall issues)
4. Use the Supabase Dashboard SQL Editor as an alternative for running SQL














