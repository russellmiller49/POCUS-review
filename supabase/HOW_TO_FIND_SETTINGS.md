# How to Find Cursor Settings.json File

## Method 1: Open via Terminal (Easiest)

I've opened the folder for you! You should see a Finder window with the `User` folder.

Look for the file named `settings.json` in that folder.

## Method 2: Navigate Manually in Finder

1. **Open Finder**
2. **Press `Cmd+Shift+G`** (this opens "Go to Folder")
3. **Paste this path:**
   ```
   ~/Library/Application Support/Cursor/User
   ```
4. **Press Enter**
5. You'll see the `settings.json` file

## Method 3: Show Hidden Files (If Library is Hidden)

If you can't see the `Library` folder:

1. **Open Finder**
2. **Press `Cmd+Shift+.`** (period) to show hidden files
3. **Navigate to:** `Users` → `russellmiller` → `Library` → `Application Support` → `Cursor` → `User`
4. Find `settings.json`

## Method 4: Open Directly in Cursor

1. **In Cursor, press `Cmd+Shift+P`**
2. **Type:** `Preferences: Open User Settings (JSON)`
3. **Press Enter**
4. This will open the settings.json file directly in Cursor!

## What to Do Once You Find It

1. Open `settings.json` in any text editor (Cursor, TextEdit, etc.)
2. Find the line that says: `"Authorization": "Bearer YOUR_SUPABASE_ACCESS_TOKEN_HERE"`
3. Replace `YOUR_SUPABASE_ACCESS_TOKEN_HERE` with your actual Supabase access token
4. Save the file
5. Restart Cursor

## Get Your Supabase Access Token

1. Go to: https://supabase.com/dashboard/account/tokens
2. Click "Generate New Token"
3. Name it "Cursor MCP"
4. Copy the token

## Quick Command to Edit

If you want to edit it from terminal, you can run:
```bash
nano ~/Library/Application\ Support/Cursor/User/settings.json
```

Or use any editor you prefer!













