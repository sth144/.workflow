#!/bin/bash
# Slack helper functions for Claude routines

SLACK_WEBHOOK_URL_FILE="$HOME/.config/.env.SLACK_WEBHOOK_URL"
SLACK_BOT_TOKEN_FILE="$HOME/.config/.env.SLACK_BOT_TOKEN"
SLACK_USER_TOKEN_FILE="$HOME/.config/.env.SLACK_USER_TOKEN"

# Post a message to Slack via webhook
# Usage: slack_post "message text"
slack_post() {
  local message="$1"
  if [[ -f "$SLACK_WEBHOOK_URL_FILE" ]]; then
    local webhook_url
    webhook_url=$(cat "$SLACK_WEBHOOK_URL_FILE")
    curl -s -X POST -H 'Content-type: application/json' \
    --data "{\"text\": $(echo "$message" | jq -Rs .)}" \
    "$webhook_url" > /dev/null
  else
    echo "[slack] No webhook URL configured at $SLACK_WEBHOOK_URL_FILE" >&2
  fi
}

# Post a rich message with blocks
# Usage: slack_post_blocks '{"blocks": [...]}'
slack_post_blocks() {
  local payload="$1"
  if [[ -f "$SLACK_WEBHOOK_URL_FILE" ]]; then
    local webhook_url
    webhook_url=$(cat "$SLACK_WEBHOOK_URL_FILE")
    curl -s -X POST -H 'Content-type: application/json' \
      --data "$payload" \
      "$webhook_url" > /dev/null
  fi
}

# Post using Bot API (for channels not covered by webhook)
# Usage: slack_api_post "#channel" "message"
slack_api_post() {
  local channel="$1"
  local message="$2"
  if [[ -f "$SLACK_BOT_TOKEN_FILE" ]]; then
    local token
    token=$(cat "$SLACK_BOT_TOKEN_FILE")
    curl -s -X POST \
      -H "Authorization: Bearer $token" \
      -H 'Content-type: application/json' \
      --data "{\"channel\": \"$channel\", \"text\": $(echo "$message" | jq -Rs .)}" \
      "https://slack.com/api/chat.postMessage" > /dev/null
  else
    echo "[slack] No bot token configured at $SLACK_BOT_TOKEN_FILE" >&2
  fi
}

# Read messages from a channel (requires user token)
# Usage: slack_read "C12345" [limit]
# Returns JSON array of messages
slack_read() {
    local channel="$1"
    local limit="${2:-10}"
    if [[ -f "$SLACK_USER_TOKEN_FILE" ]]; then
        local token
        token=$(cat "$SLACK_USER_TOKEN_FILE")
        curl -s -H "Authorization: Bearer $token" \
            "https://slack.com/api/conversations.history?channel=$channel&limit=$limit"
    else
        echo "[slack] No user token configured at $SLACK_USER_TOKEN_FILE" >&2
        return 1
    fi
}

# List channels the user is in
# Usage: slack_channels [limit]
slack_channels() {
    local limit="${1:-100}"
    if [[ -f "$SLACK_USER_TOKEN_FILE" ]]; then
        local token
        token=$(cat "$SLACK_USER_TOKEN_FILE")
        curl -s -H "Authorization: Bearer $token" \
            "https://slack.com/api/conversations.list?limit=$limit&types=public_channel,private_channel"
    else
        echo "[slack] No user token configured at $SLACK_USER_TOKEN_FILE" >&2
        return 1
    fi
}

# Search messages
# Usage: slack_search "query"
slack_search() {
    local query="$1"
    if [[ -f "$SLACK_USER_TOKEN_FILE" ]]; then
        local token
        token=$(cat "$SLACK_USER_TOKEN_FILE")
        curl -s -H "Authorization: Bearer $token" \
            --data-urlencode "query=$query" \
            "https://slack.com/api/search.messages"
    else
        echo "[slack] No user token configured at $SLACK_USER_TOKEN_FILE" >&2
        return 1
    fi
}
