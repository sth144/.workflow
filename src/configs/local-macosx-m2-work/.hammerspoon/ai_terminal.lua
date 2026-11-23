return {
  name = "Claude",
  yoloMarker = "HS-CLAUDE-YOLO",
  yoloCommand = "unset CLAUDECODE CLAUDE_CODE_ENTRYPOINT CLAUDE_CODE_CHILD_SESSION && export NVM_DIR=~/.nvm && source ~/.nvm/nvm.sh && cd ~ && claude --dangerously-skip-permissions",
  yoloApp = "Claude YOLO",
  daybookSession = os.getenv("HOME") .. "/.claude/routines/daybook-interview-session.command",
}
