# How to Find MCP Settings in Cursor

Based on your system, Cursor has MCP support (I found MCP logs). Here's how to access it:

## Method 1: Command Palette

1. Press `Cmd+Shift+P` (Mac) or `Ctrl+Shift+P` (Windows/Linux)
2. Type: `MCP` or `Model Context Protocol`
3. Look for commands like:
   - "MCP: Configure Servers"
   - "MCP: Add Server"
   - "MCP: Open Settings"

## Method 2: Settings Search

1. Open Settings: `Cmd+,` (Mac) or `Ctrl+,` (Windows/Linux)
2. In the search bar, type: `mcp`
3. Look for MCP-related settings

## Method 3: Direct Settings File

MCP servers might be configured directly in the settings JSON:

1. Open Settings: `Cmd+,`
2. Click the `{}` icon in the top right (Open Settings JSON)
3. Add this configuration:

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

## Method 4: Check Cursor Version

MCP support might require a specific Cursor version:
1. Go to: Cursor → About Cursor (or Help → About)
2. Check your version
3. Update if needed: Cursor → Check for Updates

## Method 5: Alternative - Use Cursor's Built-in Supabase Tools

If MCP isn't available, you can still work with Supabase through:
- The terminal (using `supabase` CLI)
- Direct SQL queries via Supabase Dashboard
- I can help you run commands directly

## Quick Test

Try this in Command Palette (`Cmd+Shift+P`):
- Type: `@mcp` or `mcp server`

If nothing appears, MCP might not be enabled in your Cursor version, or it might be in a different location.

Let me know what you find!

