# How to Add MCP Server to Cursor

Since MCP settings might not be visible in the UI, here's how to add it manually:

## Method 1: Add to settings.json (Recommended)

1. **Open Cursor Settings File:**
   - Press `Cmd+Shift+P` (Mac) or `Ctrl+Shift+P` (Windows/Linux)
   - Type "Preferences: Open User Settings (JSON)"
   - Press Enter

2. **Add MCP Configuration:**
   Add this to your settings.json file:

```json
{
  "mcpServers": {
    "supabase": {
      "url": "https://mcp.supabase.com/mcp?project_ref=tqnhxlwvkkswuckszlee",
      "headers": {
        "Authorization": "Bearer YOUR_SUPABASE_ACCESS_TOKEN_HERE"
      }
    }
  }
}
```

**Important:** Replace `YOUR_SUPABASE_ACCESS_TOKEN_HERE` with your actual token from:
https://supabase.com/dashboard/account/tokens

3. **Save and Restart Cursor**

## Method 2: Check if MCP is in a separate config file

Cursor might store MCP config in a separate location. Try:

1. Check if there's an MCP extension installed
2. Look for MCP settings in the Command Palette:
   - Press `Cmd+Shift+P`
   - Type "MCP" to see available commands

## Method 3: Use the Cursor MCP Extension

If Cursor has a built-in MCP extension:

1. Press `Cmd+Shift+X` to open Extensions
2. Search for "MCP" or "Model Context Protocol"
3. Install if available
4. Configure through the extension settings

## Get Your Supabase Access Token

1. Go to: https://supabase.com/dashboard/account/tokens
2. Click "Generate New Token"
3. Name it "Cursor MCP"
4. Copy the token (you won't see it again!)

## Verify It's Working

After adding the config and restarting Cursor, you can test by asking me:
- "List my Supabase tables"
- "Check my RLS policies"
- "Run a query on my database"

If I can access your Supabase database, the MCP server is working!

## Troubleshooting

If it still doesn't work:
1. Make sure you're using the latest version of Cursor
2. Check Cursor's release notes for MCP support
3. The MCP feature might be in beta - check Cursor's documentation
4. Try the command-line approach (see Method 4 below)

## Method 4: Alternative - Use Supabase CLI Directly

If MCP doesn't work, we can continue using the Supabase CLI with the connection string approach we've been using. It's less convenient but still functional.






