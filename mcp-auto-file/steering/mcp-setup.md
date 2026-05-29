---
inclusion: manual
---

# MCP Server Setup Guide

When the user asks to "set up MCP", "configure MCP servers", or similar, follow this workflow conversationally.

## Available MCP Servers

| # | Server ID | Name | Requires |
|---|-----------|------|----------|
| 1 | nmidp-mcp | Developer Portal | NMIDP_API_TOKEN |
| 2 | jira-mcp | Jira | JIRA_ETEAM_TOKEN |
| 3 | confluence-mcp | Confluence | CONFLUENCE_ETEAM_TOKEN |
| 4 | gerrit-mcp | Gerrit | GERRIT_USERNAME, GERRIT_PASSWORD |
| 5 | jenkins-mcp | Jenkins | (none — uses signum) |
| 6 | arm-mcp | ARM | ARM_TOKEN |
| 7 | e-ui-sdk-mcp | E-UI SDK | (none) |

## Workflow

### Step 1: Ask for signum
Ask the user for their Ericsson signum. This is used as `ANALYTICS_USERNAME` and to set `HOME` paths.

### Step 2: Ask which servers
Present the list above and ask which ones they want configured. Accept numbers, names, or "all".

### Step 3: Collect tokens
For each selected server that requires credentials, ask the user for the token/credentials one at a time. Provide the source location for each:

- **NMIDP_API_TOKEN**: Developer Portal > Settings > General > Copy Refresh Token - MCP
- **JIRA_ETEAM_TOKEN**: Jira > User Profile > Personal Access Tokens
- **CONFLUENCE_ETEAM_TOKEN**: Confluence > User Profile > Personal Access Tokens
- **GERRIT_USERNAME / GERRIT_PASSWORD**: Gerrit > Settings > HTTP Credentials
- **ARM_TOKEN**: ARM > User Profile > Access Token

### Step 4: Generate the config
Write the file to `~/.kiro/settings/mcp.json` with this structure:

```json
{
  "mcpServers": {
    "<server-id>": {
      "env": {
        // server-specific env vars
      },
      "disabled": false,
      "autoApprove": []
    }
  }
}
```

#### Server templates:

**nmidp-mcp:**
```json
"nmidp-mcp": {
  "env": {
    "HOME": "/home/{signum}",
    "NMIDP_API_TOKEN": "{token}"
  },
  "disabled": false,
  "autoApprove": []
}
```

**jira-mcp:**
```json
"jira-mcp": {
  "env": {
    "JIRA_ETEAM_TOKEN": "{token}",
    "ANALYTICS_USERNAME": "{signum}"
  },
  "disabled": false,
  "autoApprove": []
}
```

**confluence-mcp:**
```json
"confluence-mcp": {
  "env": {
    "CONFLUENCE_ETEAM_TOKEN": "{token}",
    "ANALYTICS_USERNAME": "{signum}"
  },
  "disabled": false,
  "autoApprove": []
}
```

**gerrit-mcp:**
```json
"gerrit-mcp": {
  "env": {
    "GERRIT_USERNAME": "{username}",
    "GERRIT_PASSWORD": "{password}",
    "ANALYTICS_USERNAME": "{signum}"
  },
  "disabled": false,
  "autoApprove": []
}
```

**jenkins-mcp:**
```json
"jenkins-mcp": {
  "env": {
    "HOME": "/home/{signum}",
    "ANALYTICS_USERNAME": "{signum}"
  },
  "disabled": false,
  "autoApprove": []
}
```

**arm-mcp:**
```json
"arm-mcp": {
  "env": {
    "ARM_TOKEN": "{token}",
    "ANALYTICS_USERNAME": "{signum}"
  },
  "disabled": false,
  "autoApprove": []
}
```

**e-ui-sdk-mcp:**
```json
"e-ui-sdk-mcp": {
  "env": {},
  "disabled": false,
  "autoApprove": []
}
```

### Step 5: Confirm and advise
After writing the file:
1. Tell the user the config was written to `~/.kiro/settings/mcp.json`
2. Tell them to reconnect MCP servers (Command Palette > "MCP: Reconnect Servers")
3. Warn that NMIDP_API_TOKEN expires every 24h if they configured nmidp-mcp
4. Offer to help refresh it anytime — they can just say "refresh my NMIDP token"

## Token Refresh Flow

When the user asks to "refresh token", "update NMIDP token", or similar:
1. Ask which token (if ambiguous)
2. Ask for the new token value
3. Read the existing `~/.kiro/settings/mcp.json`
4. Update only the relevant token field
5. Write the file back
6. Confirm and remind them to reconnect MCP servers

## Important Notes
- If `~/.kiro/settings/mcp.json` already exists, read it first and merge — don't overwrite servers the user didn't select.
- Never echo token values back to the user after they provide them.
- If the user provides a token that looks empty or malformed (very short, contains spaces), warn them but proceed if they confirm.
