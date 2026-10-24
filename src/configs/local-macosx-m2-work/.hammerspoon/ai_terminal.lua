return {
  name = "Claude",
  yoloMarker = "HS-CLAUDE-YOLO",
  -- `opus` is an alias for the latest Opus, so this does not need editing when
  -- a new one ships. Pinning a full id here is what left the pad on an old model.
  yoloCommand = "unset CLAUDECODE CLAUDE_CODE_ENTRYPOINT && cd ~ && claude --model opus --dangerously-skip-permissions",
  yoloApp = "Claude YOLO",
  daybookSession = os.getenv("HOME") .. "/.claude/routines/daybook-interview-session.command",
}
