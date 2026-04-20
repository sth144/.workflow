# Skill: Slack Integration

## When to Use

Use this skill when the user wants to interact with Slack: read messages, send
messages, search, list channels, or DM someone. Trigger phrases include:
"slack", "send a message", "check slack", "DM", "post to #channel",
"recent messages from".

## IMPORTANT: Bot Signature

When sending messages on Sean's behalf, **always append the bot signature**:

```
[🤖 Sean Hinds Bot]
```

Example message:
```
Hey, just checking in on the status of that PR!

[🤖 Sean Hinds Bot]
```

This makes it clear to recipients that the message was sent by Claude, not Sean directly.

## Prerequisites

Credentials stored in `~/.config/`:
- `.env.SLACK_WEBHOOK_URL` — for simple posting to a configured channel
- `.env.SLACK_BOT_TOKEN` (`xoxb-...`) — for bot actions
- `.env.SLACK_USER_TOKEN` (`xoxp-...`) — for user-level access (read any channel user is in)

## Token Types

| Token | Prefix | Use Case |
|-------|--------|----------|
| Bot | `xoxb-` | Post messages, limited to channels bot is in |
| User | `xoxp-` | Read/write any channel the user has access to |
| Webhook | URL | Simple POST to one configured channel |

**Prefer the user token** for most operations since it has broader access.

## Critical: API Request Format

### Use Form Data, NOT JSON

The Slack API is picky about JSON encoding. **Always use `-F` (form data) instead
of `-d` (JSON body)** to avoid `invalid_json` errors with special characters:

```bash
# ✅ CORRECT - form data
curl -s -X POST "https://slack.com/api/chat.postMessage" \
  -H "Authorization: Bearer $TOKEN" \
  -F "channel=C12345" \
  -F "text=Hello! 🤖"

# ❌ WRONG - often fails with emojis or special chars
curl -s -X POST "https://slack.com/api/chat.postMessage" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"channel":"C12345","text":"Hello! 🤖"}'
```

### Avoid Piping Curl to Python

Piping `curl | python3` often fails silently. Save to file first:

```bash
# ✅ CORRECT
curl -s ... -o /tmp/response.json
python3 -c "import json; data = json.load(open('/tmp/response.json')); ..."

# ❌ UNRELIABLE
curl -s ... | python3 -c "import json, sys; data = json.load(sys.stdin); ..."
```

## Common Operations

### Read Messages from a Channel

```bash
TOKEN=$(cat ~/.config/.env.SLACK_USER_TOKEN)
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://slack.com/api/conversations.history?channel=CHANNEL_ID&limit=10"
```

### Send a Message

```bash
TOKEN=$(cat ~/.config/.env.SLACK_USER_TOKEN)
curl -s -X POST "https://slack.com/api/chat.postMessage" \
  -H "Authorization: Bearer $TOKEN" \
  -F "channel=CHANNEL_ID" \
  -F "text=Your message here

[🤖 Sean Hinds Bot]"
```

### Send a DM

First open the DM conversation, then send:

```bash
TOKEN=$(cat ~/.config/.env.SLACK_USER_TOKEN)

# Step 1: Open DM (get channel ID)
DM_RESPONSE=$(curl -s -X POST "https://slack.com/api/conversations.open" \
  -H "Authorization: Bearer $TOKEN" \
  -F "users=USER_ID")

CHANNEL_ID=$(echo "$DM_RESPONSE" | python3 -c "
import json, sys
print(json.load(sys.stdin)['channel']['id'])
")

# Step 2: Send message (always include bot signature)
curl -s -X POST "https://slack.com/api/chat.postMessage" \
  -H "Authorization: Bearer $TOKEN" \
  -F "channel=$CHANNEL_ID" \
  -F "text=Hello!

[🤖 Sean Hinds Bot]"
```

### Find a User by Name

```bash
TOKEN=$(cat ~/.config/.env.SLACK_USER_TOKEN)
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://slack.com/api/users.list?limit=500" -o /tmp/users.json

python3 -c "
import json
with open('/tmp/users.json') as f:
    data = json.load(f)
for u in data.get('members', []):
    name = u.get('real_name', '').lower()
    if 'search_name' in name:
        print(f\"{u['id']} | {u.get('real_name')} | @{u.get('name')}\")
"
```

### List Channels

```bash
TOKEN=$(cat ~/.config/.env.SLACK_USER_TOKEN)
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://slack.com/api/conversations.list?limit=100&types=public_channel,private_channel"
```

### Search Messages

```bash
TOKEN=$(cat ~/.config/.env.SLACK_USER_TOKEN)
curl -s -H "Authorization: Bearer $TOKEN" \
  -G --data-urlencode "query=search term" \
  "https://slack.com/api/search.messages"
```

### Post via Webhook (Simplest)

No auth header needed, just POST:

```bash
WEBHOOK=$(cat ~/.config/.env.SLACK_WEBHOOK_URL)
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"text":"Message here\n\n[🤖 Sean Hinds Bot]"}' \
  "$WEBHOOK"
```

## Required Scopes by Operation

| Operation | Scopes Needed |
|-----------|---------------|
| List channels | `channels:read`, `groups:read` |
| Read channel history | `channels:history`, `groups:history` |
| Read DMs | `im:history` |
| Send messages | `chat:write` |
| Open/send DMs | `im:write`, `chat:write` |
| Join channels | `channels:join` |
| Search messages | `search:read` |
| List users | `users:read` |

If you get `missing_scope` errors, add the needed scope in **OAuth & Permissions**
→ **User Token Scopes**, then **reinstall** the app.

## Helper Library

A bash helper library is available at `~/.claude/routines/lib/slack.sh`:

```bash
source ~/.claude/routines/lib/slack.sh

slack_post "Message"              # Post via webhook
slack_api_post "#channel" "Msg"   # Post via bot token
slack_read "CHANNEL_ID" 10        # Read messages (user token)
slack_channels                    # List channels
slack_search "query"              # Search messages
```

## Error Handling

| Error | Cause | Fix |
|-------|-------|-----|
| `missing_scope` | Token lacks required permission | Add scope, reinstall app |
| `not_in_channel` | Bot not a member | Invite bot or use user token |
| `invalid_json` | JSON encoding issue | Use form data (`-F`) instead |
| `channel_not_found` | Wrong channel ID | List channels to find correct ID |
| `invalid_auth` | Bad or expired token | Regenerate token |

## Workspace Info

- **Workspace**: lab7io.slack.com
- **Team ID**: T3EB8JVQF
- **Common channels**:
  - `#general`: C3EAWJJDU
  - `#random`: C3DP0JSPP
  - `#notifications`: C3FB80ED9
