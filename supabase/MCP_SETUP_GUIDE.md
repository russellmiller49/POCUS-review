# Supabase MCP Server Setup Guide

This guide will help you set up the Supabase MCP server in Cursor to make database management easier.

## Prerequisites

- Node.js v22.16.0 ✅ (installed)
- pnpm ✅ (installed)
- Supabase project: `tqnhxlwvkkswuckszlee`

## Option 1: Using the Hosted MCP Server (Recommended)

The Supabase MCP server is available as a hosted service at `https://mcp.supabase.com/mcp`.

### Step 1: Get Your Supabase Access Token

1. Go to: https://supabase.com/dashboard/account/tokens
2. Create a new access token (or use an existing one)
3. Copy the token

### Step 2: Configure in Cursor

1. Open Cursor Settings (Cmd+, on Mac)
2. Go to "Features" → "Model Context Protocol" or search for "MCP"
3. Add a new MCP server with these settings:

**For Cursor Settings JSON:**
```json
{
  "mcpServers": {
    "supabase": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-supabase",
        "--access-token", "YOUR_ACCESS_TOKEN_HERE",
        "--project-ref", "tqnhxlwvkkswuckszlee"
      ]
    }
  }
}
```

**Or use the hosted URL approach:**
```json
{
  "mcpServers": {
    "supabase": {
      "url": "https://mcp.supabase.com/mcp",
      "headers": {
        "Authorization": "Bearer YOUR_ACCESS_TOKEN_HERE"
      },
      "params": {
        "project_ref": "tqnhxlwvkkswuckszlee"
      }
    }
  }
}
```

## Option 2: Install Locally

### Step 1: Clone and Install

```bash
cd /Users/russellmiller/Projects/POCUS_APP
git clone https://github.com/supabase-community/supabase-mcp.git
cd supabase-mcp
pnpm install
```

### Step 2: Build

```bash
pnpm build
```

### Step 3: Configure Environment

Create a `.env` file in the `supabase-mcp` directory:

```bash
SUPABASE_ACCESS_TOKEN=your_access_token_here
SUPABASE_PROJECT_REF=tqnhxlwvkkswuckszlee
```

### Step 4: Configure in Cursor

```json
{
  "mcpServers": {
    "supabase": {
      "command": "node",
      "args": [
        "/Users/russellmiller/Projects/POCUS_APP/supabase-mcp/packages/mcp-server/dist/index.js",
        "--access-token", "${SUPABASE_ACCESS_TOKEN}",
        "--project-ref", "tqnhxlwvkkswuckszlee"
      ],
      "env": {
        "SUPABASE_ACCESS_TOKEN": "your_access_token_here"
      }
    }
  }
}
```

## Your Project Details

- **Project Reference ID**: `tqnhxlwvkkswuckszlee`
- **Project Name**: Endoreels
- **Region**: us-west-1
- **Service Role Key**: (stored in your config)

## Available MCP Tools

Once configured, you'll have access to:

- **Database Tools**: `list_tables`, `execute_sql`, `apply_migration`, `list_migrations`
- **Debugging Tools**: `get_logs`, `get_advisors`
- **Development Tools**: `get_project_url`, `generate_typescript_types`
- **Edge Functions**: `list_edge_functions`, `deploy_edge_function`
- **Storage**: `list_storage_buckets` (if enabled)

## Security Notes

- Use a development project, not production
- The MCP server operates with your developer permissions
- Review all tool calls before executing
- Consider using read-only mode for sensitive data

## Next Steps

1. Get your Supabase access token from the dashboard
2. Configure the MCP server in Cursor settings
3. Test by asking me to list your tables or run a query

For more information, see: https://github.com/supabase-community/supabase-mcp













