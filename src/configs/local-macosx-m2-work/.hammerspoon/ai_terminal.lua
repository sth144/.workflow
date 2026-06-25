return {
  name = "Claude",
  yoloMarker = "HS-CLAUDE-YOLO",
  yoloCommand = "unset CLAUDECODE CLAUDE_CODE_ENTRYPOINT && cd ~ && claude --dangerously-skip-permissions",
  yoloApp = "Claude YOLO",
  daybookSession = os.getenv("HOME") .. "/.claude/routines/daybook-interview-session.command",
}
