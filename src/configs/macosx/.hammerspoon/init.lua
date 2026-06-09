-- ~/.hammerspoon/init.lua
-- i3-style scratchpad implementation for macOS
--
-- Symlink this file to ~/.hammerspoon/init.lua:
--   ln -sf ~/src/workflow-macos-1095/src/configs/macosx/.hammerspoon/init.lua ~/.hammerspoon/init.lua
--
-- Prerequisites:
--   brew install --cask hammerspoon
--   Grant Accessibility permission in System Settings > Privacy & Security

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

-- Define scratchpads here. Each entry creates a toggle-able floating window.
-- Use bundle IDs for reliability (app names can be flaky).
--
-- Find bundle ID with: osascript -e 'id of app "AppName"'
-- Common ones:
--   Alacritty:  io.alacritty
--   kitty:      net.kovidgoyal.kitty
--   iTerm2:     com.googlecode.iterm2
--   Terminal:   com.apple.Terminal
--   Warp:       dev.warp.Warp-Stable

-- Modifier used for all scratchpads (Cmd+Ctrl avoids conflicts with macOS/apps)
local mod = { "cmd", "ctrl" }

-- i3 scratchpad mappings for macOS
-- Key mapping rationale:
--   i3 uses Alt (mod1) but macOS Option+letter types special chars (é, ñ, etc.)
--   So we use Cmd+Ctrl which is rarely used by macOS or apps
--
-- | i3 Key  | App         | macOS Key    |
-- |---------|-------------|--------------|
-- | Alt+U   | Terminal    | Cmd+Ctrl+U   |
-- | Alt+J   | Joplin      | Cmd+Ctrl+J   |
-- | Alt+C   | Calendar    | Cmd+Ctrl+C   |
-- | Alt+I   | Ranger      | Cmd+Ctrl+I   |
-- | Alt+T   | Trello      | Cmd+Ctrl+T   |
-- | Alt+F12 | ChatGPT     | Cmd+Ctrl+A   |
-- | Alt+F11 | Calculator  | Cmd+Ctrl+K   |
-- | Alt+R   | Research    | Cmd+Ctrl+R   |
-- | Alt+D   | Draw        | Cmd+Ctrl+O   |
-- | —       | Slack       | Cmd+Ctrl+S   |
-- | —       | VS Code     | Cmd+Ctrl+E   |
-- | —       | Forks       | Cmd+Ctrl+F   |
-- | —       | DiffToggle  | Cmd+Ctrl+D   |

local scratchpads = {
  -- Terminal (i3: Alt+U)
  terminal = {
    bundleID = "com.googlecode.iterm2",
    hotkey   = mod,
    key      = "u",
    width    = 0.5,
    height   = 0.55,
  },

  -- Joplin notes (i3: Alt+J)
  joplin = {
    bundleID = "net.cozic.joplin-desktop",
    hotkey   = mod,
    key      = "j",
    width    = 0.6,
    height   = 0.75,
  },

  -- Calendar (i3: Alt+C)
  calendar = {
    bundleID = "com.apple.iCal",
    hotkey   = mod,
    key      = "c",
    width    = 0.7,
    height   = 0.8,
  },

  -- Ranger file manager in iTerm2 (i3: Alt+I)
  -- NOTE: This uses a custom handler, not the standard toggleScratchpad
  ranger = {
    hotkey      = mod,
    key         = "i",
    width       = 0.8,
    height      = 0.85,
    windowTitle = "ranger",  -- iTerm2 window title to look for
  },


  -- Trello (i3: Alt+T)
  trello = {
    bundleID = "com.atlassian.trello",
    hotkey   = mod,
    key      = "t",
    width    = 0.7,
    height   = 0.8,
  },

  -- Claude AI (i3: Alt+F12 for ChatGPT)
  claude = {
    bundleID = "com.anthropic.claudefordesktop",
    hotkey   = mod,
    key      = "a",
    width    = 0.5,
    height   = 0.7,
  },

  -- bc calculator in iTerm2 (i3: Alt+F11)
  -- NOTE: This uses a custom handler, not the standard toggleScratchpad
  calculator = {
    hotkey      = mod,
    key         = "k",
    width       = 0.28,
    height      = 0.32,
    windowTitle = "bc",
  },

  -- Chrome for research (i3: Alt+R)
  browser = {
    bundleID = "com.google.Chrome",
    hotkey   = mod,
    key      = "r",
    width    = 0.8,
    height   = 0.85,
  },

  -- LibreOffice Draw (i3: Alt+Shift+D)
  draw = {
    bundleID = "org.libreoffice.script",
    hotkey   = mod,
    key      = "o",
    width    = 0.8,
    height   = 0.85,
  },

  -- Slack (no i3 equivalent)
  slack = {
    bundleID = "com.tinyspeck.slackmacgap",
    hotkey   = mod,
    key      = "s",
    width    = 0.6,
    height   = 0.75,
  },

  -- VS Code editor (no i3 equivalent)
  editor = {
    bundleID = "com.microsoft.VSCode",
    hotkey   = mod,
    key      = "e",
    width    = 0.85,
    height   = 0.9,
  },

  -- Claude Code forks (tmux pane multiplexer)
  -- NOTE: This uses a custom handler, not the standard toggleScratchpad.
  -- fork_session.sh creates the session and adds panes; this just toggles visibility.
  forks = {
    hotkey      = mod,
    key         = "f",
    width       = 0.85,
    height      = 0.9,
    windowTitle = "claude-forks",
  },
}

--------------------------------------------------------------------------------
-- Scratchpad toggle logic
--------------------------------------------------------------------------------

local function toggleScratchpad(config)
  local app = hs.application.get(config.bundleID)

  -- If app is frontmost, hide it (dismiss scratchpad)
  if app and app:isFrontmost() then
    app:hide()
    return
  end

  -- Otherwise, launch/focus and position as floating centered window
  hs.application.launchOrFocusByBundleID(config.bundleID)

  -- Wait briefly for app to launch if it wasn't running
  hs.timer.doAfter(0.1, function()
    app = hs.application.get(config.bundleID)
    if not app then return end

    local win = app:mainWindow()
    if not win then return end

    -- Center on main screen at configured size
    local screen = hs.screen.mainScreen()
    local f = screen:frame()
    local w = f.w * config.width
    local h = f.h * config.height

    win:setFrame({
      x = f.x + (f.w - w) / 2,
      y = f.y + (f.h - h) / 2,
      w = w,
      h = h,
    })

    win:raise()
    win:focus()
  end)
end

--------------------------------------------------------------------------------
-- iTerm2 scratchpad helper
-- Simple approach: iterate windows and match by title
--------------------------------------------------------------------------------

local function positionWindow(win, config)
  if not win then return end
  local screen = hs.screen.mainScreen()
  local f = screen:frame()
  local w = f.w * config.width
  local h = f.h * config.height
  win:setFrame({
    x = f.x + (f.w - w) / 2,
    y = f.y + (f.h - h) / 2,
    w = w,
    h = h,
  })
end

local function findItermWindowByTitle(marker)
  local iterm = hs.application.get("com.googlecode.iterm2")
  if not iterm then return nil end

  for _, win in ipairs(iterm:allWindows()) do
    local title = win:title()
    if title and string.find(title, marker, 1, true) then
      return win
    end
  end
  return nil
end

local function toggleItermScratchpad(titleMarker, command, config)
  local scratchWin = findItermWindowByTitle(titleMarker)

  if scratchWin then
    -- Window exists
    local focused = hs.window.focusedWindow()
    if focused and focused:id() == scratchWin:id() then
      -- It's focused - hide the app
      scratchWin:application():hide()
    else
      -- Not focused - bring it up and position
      scratchWin:application():unhide()
      positionWindow(scratchWin, config)
      scratchWin:raise()
      scratchWin:focus()
    end
  else
    -- No window found - create one
    local createScript = string.format([[
      tell application "iTerm"
        activate
        set newWindow to (create window with default profile)
        tell current session of newWindow
          write text "printf '\\033]0;%s\\007'; %s"
        end tell
      end tell
    ]], titleMarker, command)
    hs.osascript.applescript(createScript)

    -- Position after delay
    hs.timer.doAfter(0.5, function()
      local win = findItermWindowByTitle(titleMarker)
      if win then
        positionWindow(win, config)
      end
    end)
  end
end

local function toggleRanger()
  toggleItermScratchpad("HS-RANGER", "ranger", scratchpads.ranger)
end

local function toggleBcCalc()
  toggleItermScratchpad("HS-CALC", "bc -l", scratchpads.calculator)
end

local function toggleClaudeForks()
  toggleItermScratchpad("HS-FORKS", "tmux new-session -A -s claude-forks", scratchpads.forks)
end

--------------------------------------------------------------------------------
-- Bind hotkeys
--------------------------------------------------------------------------------

for name, config in pairs(scratchpads) do
  -- Custom handlers for terminal-based scratchpads
  if name == "ranger" then
    hs.hotkey.bind(config.hotkey, config.key, toggleRanger)
  elseif name == "calculator" then
    hs.hotkey.bind(config.hotkey, config.key, toggleBcCalc)
  elseif name == "forks" then
    hs.hotkey.bind(config.hotkey, config.key, toggleClaudeForks)
  elseif config.bundleID then
    hs.hotkey.bind(config.hotkey, config.key, function()
      toggleScratchpad(config)
    end)
  end
end

--------------------------------------------------------------------------------
-- Auto-reload config on change
--------------------------------------------------------------------------------

local function reloadConfig(files)
  local doReload = false
  for _, file in pairs(files) do
    if file:sub(-4) == ".lua" then
      doReload = true
    end
  end
  if doReload then
    hs.reload()
  end
end

hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reloadConfig):start()

--------------------------------------------------------------------------------
-- Utility hotkeys
--------------------------------------------------------------------------------

-- Toggle Claude Code diff tab hook (Cmd+Ctrl+D)
hs.hotkey.bind(mod, "d", function()
  local flag = os.getenv("HOME") .. "/.claude/hooks/diff-tab.disabled"
  local f = io.open(flag, "r")
  if f then
    f:close()
    os.remove(flag)
    hs.notify.new({ title = "Claude Code", informativeText = "Diff tabs ON" }):send()
  else
    f = io.open(flag, "w")
    if f then f:close() end
    hs.notify.new({ title = "Claude Code", informativeText = "Diff tabs OFF" }):send()
  end
end)

hs.alert.show("Hammerspoon config loaded")
