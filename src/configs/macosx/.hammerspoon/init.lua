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
--   Alacritty:  org.alacritty
--   kitty:      net.kovidgoyal.kitty
--   iTerm2:     com.googlecode.iterm2
--   Terminal:   com.apple.Terminal
--   Warp:       dev.warp.Warp-Stable

-- Load the IPC module so the `hs` command-line tool can drive/introspect the
-- running config (used for debugging scratchpad toggles from a shell).
require("hs.ipc")

-- Prompt for Accessibility on first launch; without it macOS blocks global
-- hotkeys even though Hammerspoon can load the config successfully.
hs.accessibilityState(true)

-- Modifier used for all scratchpads (Cmd+Ctrl avoids conflicts with macOS/apps)
local mod = { "cmd", "ctrl" }

local function fileExists(path)
  return hs.fs.attributes(path, "mode") ~= nil
end

local function aiTerminalConfig()
  local home = os.getenv("HOME")
  local configPath = home .. "/.hammerspoon/ai_terminal.lua"
  if fileExists(configPath) then
    local ok, config = pcall(dofile, configPath)
    if ok and type(config) == "table" then
      return config
    end
    hs.alert.show("Could not load " .. configPath)
  end

  return {
    name = "Shell",
    yoloMarker = "HS-AI-YOLO",
    yoloCommand = 'exec "$SHELL"',
    yoloApp = "Terminal",
    daybookSession = nil,
  }
end

local aiTerminal = aiTerminalConfig()

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
-- | —       | AI YOLO     | Cmd+Ctrl+Y   |
-- | —       | Daybook     | Cmd+Ctrl+B   |
-- | —       | DiffToggle  | Cmd+Ctrl+D   |

local scratchpads = {
  -- Terminal (i3: Alt+U)
  -- NOTE: custom handler (like the other terminal pads), launched through the
  -- "[Scratchpad] Terminal" wrapper so it carries a custom Dock icon/label.
  terminal = {
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

  -- Ranger file manager in Alacritty (i3: Alt+I)
  -- NOTE: This uses a custom handler, not the standard toggleScratchpad
  ranger = {
    hotkey      = mod,
    key         = "i",
    width       = 0.8,
    height      = 0.85,
    windowTitle = "ranger",  -- Alacritty window title to look for
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

  -- bc calculator in Alacritty (i3: Alt+F11)
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
    width       = 0.98,
    height      = 0.98,
    windowTitle = "claude-forks",
  },

  -- Local AI CLI in YOLO/permissive mode, launched in $HOME.
  -- NOTE: This uses a custom handler, not the standard toggleScratchpad.
  aiyolo = {
    hotkey      = mod,
    key         = "y",
    width       = 0.85,
    height      = 0.9,
    windowTitle = aiTerminal.yoloMarker,
  },

  -- Morning Daybook interview window (i3: none).
  -- NOTE: custom handler — focuses the interview window if open, otherwise launches
  -- it on demand (the same session the daily launchd job runs). Title is pinned to
  -- "Daybook" (by both launchAlacritty here and daybook-interview.sh) so it's findable.
  daybook = {
    hotkey      = mod,
    key         = "b",
    width       = 0.85,
    height      = 0.9,
    windowTitle = "Daybook",
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
-- Alacritty scratchpad helper
-- Alacritty has no AppleScript dictionary (iTerm2 did), so we drive it via its
-- CLI. To keep every scratchpad window under ONE Alacritty instance — so the
-- title search below can see all of them — we add windows with
-- `alacritty msg create-window` and only start a fresh instance when none is
-- running. Each window gets a fixed --title marker with dynamic_title disabled
-- so the running program (ranger, tmux, etc.) can't rename it out from under us.
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

-- Search EVERY running Alacritty instance, not just one. On macOS a bare
-- `alacritty ...` launch spawns a *separate* app instance (its own PID/Dock
-- entry), and `msg create-window` is unreliable here (BrokenPipe), so scratchpad
-- windows can end up under any of several instances. hs.application.get() only
-- returns one of them, so we must iterate applicationsForBundleID to find ours.
local function findAlacrittyWindowByTitle(marker)
  for _, app in ipairs(hs.application.applicationsForBundleID("org.alacritty")) do
    for _, win in ipairs(app:allWindows()) do
      local title = win:title()
      if title and string.find(title, marker, 1, true) then
        return win
      end
    end
  end
  return nil
end

-- Open a detached Alacritty window titled `marker` running `command` in a login
-- shell. We launch via `open`, NOT a bare `alacritty &`: a backgrounded child of
-- hs.execute's helper shell gets SIGHUP'd and dies the moment that shell exits,
-- whereas `open` hands the process to LaunchServices so it survives. `-n` forces
-- a fresh instance (Alacritty's `msg` IPC is unreliable on macOS — BrokenPipe),
-- and findAlacrittyWindowByTitle searches every instance so the window is still
-- discoverable. dynamic_title is pinned off so the running program (tmux, ranger,
-- bc) can't rename our marker. (command must not contain a single quote — none do.)
-- Resolve a per-scratchpad wrapper .app (built by `make install`) that gives the
-- window its own Dock/Cmd-Tab icon AND label. The bundle is named
-- "[Scratchpad] <displayName>.app" (see install.sh update_scratchpad_apps) and that
-- filename is what macOS shows in the Dock for these exec wrappers. Returns the path
-- only if it exists, so callers fall back to plain Alacritty when icons aren't installed.
local function scratchApp(displayName)
  local path = os.getenv("HOME") .. "/Applications/[Scratchpad] " .. displayName .. ".app"
  if hs.fs.attributes(path, "mode") == "directory" then
    return path
  end
  return nil
end

-- Launch a detached Alacritty window. If `appBundle` is a custom wrapper .app it is
-- used (so the window carries that wrapper's Dock icon); otherwise we fall back to
-- plain Alacritty. Either way the wrapper just exec's Alacritty, so the window stays
-- org.alacritty and findAlacrittyWindowByTitle can still see it.
-- We launch via `open`, NOT a bare `alacritty &`: a backgrounded child of
-- hs.execute's helper shell gets SIGHUP'd and dies the moment that shell exits,
-- whereas `open` hands the process to LaunchServices so it survives. `-n` forces
-- a fresh instance (Alacritty's `msg` IPC is unreliable on macOS — BrokenPipe),
-- and findAlacrittyWindowByTitle searches every instance so the window is still
-- discoverable. dynamic_title is pinned off so the running program (tmux, ranger,
-- bc) can't rename our marker. (command must not contain a single quote — none do.)
local function launchAlacritty(marker, command, appBundle)
  local app = appBundle or "/Applications/Alacritty.app"
  local shellCmd = string.format(
    "open -na '%s' --args "
      .. "--title '%s' -o window.dynamic_title=false -e bash -lc '%s'",
    app, marker, command)
  hs.execute(shellCmd, true)  -- `true` => run via login shell
end

local function toggleTermScratchpad(marker, command, config, appBundle)
  local scratchWin = findAlacrittyWindowByTitle(marker)

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
    -- No window found - create one (in its custom-icon wrapper if available)
    launchAlacritty(marker, command, appBundle)

    -- Position after delay
    hs.timer.doAfter(0.5, function()
      local win = findAlacrittyWindowByTitle(marker)
      if win then
        positionWindow(win, config)
      end
    end)
  end
end

local function toggleTerminal()
  -- Plain interactive login shell in the "[Scratchpad] Terminal" wrapper.
  toggleTermScratchpad("HS-TERMINAL", 'exec "$SHELL"', scratchpads.terminal, scratchApp("Terminal"))
end

local function toggleRanger()
  toggleTermScratchpad("HS-RANGER", "ranger", scratchpads.ranger, scratchApp("Ranger"))
end

local function toggleBcCalc()
  toggleTermScratchpad("HS-CALC", "bc ~/.bcrc -l", scratchpads.calculator, scratchApp("Calculator"))
end

local function toggleClaudeForks()
  toggleTermScratchpad("HS-FORKS", "tmux new-session -A -s claude-forks", scratchpads.forks, scratchApp("Forks"))
end

local function toggleAiYolo()
  toggleTermScratchpad(aiTerminal.yoloMarker, aiTerminal.yoloCommand, scratchpads.aiyolo, scratchApp(aiTerminal.yoloApp))
end

-- Toggle the morning Daybook interview window. If it's open, focus/hide it like
-- the other scratchpads. If it's NOT open, announce that and launch the interview
-- on demand — the same session the daily launchd job runs — so it can be started
-- by hotkey too. We launch via launchAlacritty (open -na) rather than calling
-- daybook-interview.sh: that script uses `exec alacritty`, which is fine under
-- launchd but would get SIGHUP'd and die when spawned from Hammerspoon.
local function toggleDaybook()
  local marker = "Daybook"
  local win = findAlacrittyWindowByTitle(marker)
  if win then
    local focused = hs.window.focusedWindow()
    if focused and focused:id() == win:id() then
      win:application():hide()
    else
      win:application():unhide()
      positionWindow(win, scratchpads.daybook)
      win:raise()
      win:focus()
    end
    return
  end

  if not aiTerminal.daybookSession then
    hs.alert.show("No Daybook session configured for " .. aiTerminal.name)
    return
  end

  hs.alert.show("No Daybook window — starting interview…")
  launchAlacritty(marker, "exec " .. aiTerminal.daybookSession, scratchApp("Daybook"))
  hs.timer.doAfter(0.8, function()
    local w = findAlacrittyWindowByTitle(marker)
    if w then positionWindow(w, scratchpads.daybook) end
  end)
end

--------------------------------------------------------------------------------
-- Bind hotkeys
--------------------------------------------------------------------------------

for name, config in pairs(scratchpads) do
  -- Custom handlers for terminal-based scratchpads
  if name == "terminal" then
    hs.hotkey.bind(config.hotkey, config.key, toggleTerminal)
  elseif name == "ranger" then
    hs.hotkey.bind(config.hotkey, config.key, toggleRanger)
  elseif name == "calculator" then
    hs.hotkey.bind(config.hotkey, config.key, toggleBcCalc)
  elseif name == "forks" then
    hs.hotkey.bind(config.hotkey, config.key, toggleClaudeForks)
  elseif name == "aiyolo" then
    hs.hotkey.bind(config.hotkey, config.key, toggleAiYolo)
  elseif name == "daybook" then
    hs.hotkey.bind(config.hotkey, config.key, toggleDaybook)
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
