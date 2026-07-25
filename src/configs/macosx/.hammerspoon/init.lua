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
-- | —       | ResMonitor  | Cmd+Ctrl+M   |
-- | —       | CAD Tutor   | Cmd+Ctrl+G   |
-- | —       | ScreenTutor | Cmd+Ctrl+H   |
-- | —       | ↳ cycle nook| Cmd+Ctrl+Shift+H |
-- | —       | Help panel  | Cmd+Ctrl+/   |
-- | —       | Cmd palette | Cmd+Ctrl+P   |

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

  -- CAD Tutor (FreeCAD/Blender assistant, macm4). Anchored top-right so it never
  -- covers the 3D viewport in the screen center. Custom handler via the
  -- "[Scratchpad] CAD Tutor" wrapper so it carries its own Dock icon.
  cadtutor = {
    hotkey   = mod,
    key      = "g",
    width    = 0.32,
    height   = 0.5,
    anchor   = "topright",
  },

  -- Screen Tutor (generic on-screen assistant). A translucent panel that
  -- pins to a corner (Cmd+Ctrl+H toggles; Cmd+Ctrl+Shift+H cycles corners) so it
  -- sits beside whatever app you're using without covering the center.
  screentutor = {
    hotkey   = mod,
    key      = "h",
    width    = 0.30,
    height   = 0.42,
    anchor   = "topright",
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

  -- qalc calculator in Alacritty, bc -l fallback (i3: Alt+F11)
  -- NOTE: This uses a custom handler, not the standard toggleScratchpad
  calculator = {
    hotkey      = mod,
    key         = "k",
    width       = 0.28,
    height      = 0.32,
    windowTitle = "qalc",
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
  local margin = 12
  local x, y
  local anchor = config.anchor or "center"
  if anchor == "topright" then
    x, y = f.x + f.w - w - margin, f.y + margin
  elseif anchor == "topleft" then
    x, y = f.x + margin, f.y + margin
  elseif anchor == "bottomright" then
    x, y = f.x + f.w - w - margin, f.y + f.h - h - margin
  elseif anchor == "bottomleft" then
    x, y = f.x + margin, f.y + f.h - h - margin
  elseif anchor == "right" then
    -- Full-height dock on the right edge (width from config, ~30%), leaving the
    -- rest of the screen for the app tiled beside it.
    h = f.h - 2 * margin
    x, y = f.x + f.w - w - margin, f.y + margin
  else
    x, y = f.x + (f.w - w) / 2, f.y + (f.h - h) / 2
  end
  win:setFrame({ x = x, y = y, w = w, h = h })
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
local function launchAlacritty(marker, command, appBundle, extraOpts)
  local app = appBundle or "/Applications/Alacritty.app"
  local opts = (extraOpts and extraOpts ~= "") and (" " .. extraOpts) or ""
  local shellCmd = string.format(
    "open -na '%s' --args "
      .. "--title '%s' -o window.dynamic_title=false%s -e bash -lc '%s'",
    app, marker, opts, command)
  hs.execute(shellCmd, true)  -- `true` => run via login shell
end

-- Poll for a freshly-launched window and position it the moment it appears. A
-- single fixed delay is unreliable: a cold LaunchServices start (custom wrapper
-- .app, or a harness like claude booting inside) can take longer than any one
-- guess, so the timer fires before the window exists and it stays wherever
-- Alacritty first drew it (screen center). Retry until it shows, then pin it.
local function positionWhenReady(marker, config, attempts)
  attempts = attempts or 20
  local win = findAlacrittyWindowByTitle(marker)
  if win then
    positionWindow(win, config)
  elseif attempts > 0 then
    hs.timer.doAfter(0.25, function()
      positionWhenReady(marker, config, attempts - 1)
    end)
  end
end

local function toggleTermScratchpad(marker, command, config, appBundle, extraOpts)
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
    launchAlacritty(marker, command, appBundle, extraOpts)
    -- Poll until the window actually appears, then pin it to its anchor.
    positionWhenReady(marker, config)
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
  toggleTermScratchpad("HS-CALC", "if [ -x /Users/seanhinds/bin/qalc ]; then /Users/seanhinds/bin/qalc; else bc -l ~/.bcrc; fi", scratchpads.calculator, scratchApp("Calculator"))
end

local function toggleClaudeForks()
  toggleTermScratchpad("HS-FORKS", "tmux new-session -A -s claude-forks", scratchpads.forks, scratchApp("Forks"))
end

local function toggleCadTutor()
  -- Dedicated terminal beside the CAD app for the `cad-tutor` skill. Opens a
  -- login shell (start `claude`/`codex` there, then /cad-tutor); swap the command
  -- below to auto-launch a harness if you prefer.
  toggleTermScratchpad("HS-CADTUTOR", 'exec "$SHELL"', scratchpads.cadtutor, scratchApp("CAD Tutor"))
end

-- Screen Tutor: a translucent, pinnable terminal for the `screen-tutor` skill.
-- Cmd+Ctrl+H toggles it; Cmd+Ctrl+Shift+H cycles its layout. Besides the four
-- corner nooks there's a "right" full-height dock: Screen Tutor claims a ~30%
-- column on the right and the app beside it is tiled into the rest (both usable
-- side by side), matching a CAD/QGIS + tutor workflow.
local SCREEN_TUTOR_ANCHORS = { "topright", "right", "bottomright", "bottomleft", "topleft" }
local SCREEN_TUTOR_ANCHOR_LABELS = { right = "right dock (full height)" }
local screenTutorCornerIdx = 1

-- Tile the app sitting behind Screen Tutor into the left column so it stays fully
-- visible next to the right dock. Best-effort: picks the frontmost standard,
-- non-Alacritty window (Screen Tutor itself is Alacritty, so it's skipped).
local function tileAppLeftOfScreenTutor()
  local f = hs.screen.mainScreen():frame()
  local margin = 12
  local width = scratchpads.screentutor.width
  for _, win in ipairs(hs.window.orderedWindows()) do
    local app = win:application()
    local bid = app and app:bundleID() or ""
    if win:isStandard() and bid ~= "org.alacritty" then
      win:setFrame({
        x = f.x + margin,
        y = f.y + margin,
        w = f.w * (1 - width) - 2 * margin,
        h = f.h - 2 * margin,
      })
      return
    end
  end
end

local function toggleScreenTutor()
  scratchpads.screentutor.anchor = SCREEN_TUTOR_ANCHORS[screenTutorCornerIdx]
  -- Auto-launch the claude harness straight into the /screen-tutor skill; drop to
  -- a login shell when it exits so the window persists and stays toggle-able.
  -- Sonnet by default: faster than Opus for this glance-and-explain widget, and
  -- the token-heavy visual reasoning is rare (AX/OCR handle the common cases).
  -- SCREEN_TUTOR_SESSION=1 activates the screen-tutor-consent.sh PreToolUse hook:
  -- normal tool calls run un-prompted (global Bash(*) allow), but the first screen
  -- capture per 30-min window asks for consent — no blanket yolo, no per-call nagging.
  toggleTermScratchpad("HS-SCREENTUTOR",
    'SCREEN_TUTOR_SESSION=1 claude --model sonnet /screen-tutor; exec "$SHELL"',
    scratchpads.screentutor, scratchApp("Screen Tutor"), "-o window.opacity=0.82")
  -- If the remembered layout is the right dock, tile the app beside it once the
  -- Screen Tutor window has settled into place.
  if scratchpads.screentutor.anchor == "right" then
    hs.timer.doAfter(0.5, tileAppLeftOfScreenTutor)
  end
end

local function cycleScreenTutorCorner()
  screenTutorCornerIdx = (screenTutorCornerIdx % #SCREEN_TUTOR_ANCHORS) + 1
  local corner = SCREEN_TUTOR_ANCHORS[screenTutorCornerIdx]
  scratchpads.screentutor.anchor = corner
  local win = findAlacrittyWindowByTitle("HS-SCREENTUTOR")
  if win then
    if corner == "right" then
      tileAppLeftOfScreenTutor()
    end
    positionWindow(win, scratchpads.screentutor)
    win:raise()
  end
  hs.alert.show("Screen Tutor → " .. (SCREEN_TUTOR_ANCHOR_LABELS[corner] or corner))
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
  elseif name == "cadtutor" then
    hs.hotkey.bind(config.hotkey, config.key, toggleCadTutor)
  elseif name == "screentutor" then
    hs.hotkey.bind(config.hotkey, config.key, toggleScreenTutor)
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

-- Resource Monitor floating webview (Cmd+Ctrl+M)
-- Generates a fresh report, then shows/hides it in a borderless floating window.
local resmonWebview = nil
local resmonVisible = false

local function toggleResmon()
  if resmonVisible and resmonWebview then
    resmonWebview:hide()
    resmonVisible = false
    return
  end

  -- Regenerate the report HTML (fast — reads JSONL, writes HTML)
  local venvPy = os.getenv("HOME") .. "/.cache/.workflow/resource-monitor/.venv/bin/python3"
  local script = "/usr/local/bin/monitor/resource_report.py"
  if not fileExists(script) then
    script = "/usr/local/src/workflow-macos-1095/src/utils/macosx/monitor/resource_report.py"
  end
  hs.execute(venvPy .. " " .. script .. " --no-open 2>/dev/null", true)

  local reportPath = os.getenv("HOME") .. "/.cache/.workflow/resource-monitor/report.html"
  if not hs.fs.attributes(reportPath) then
    hs.alert.show("No resource data — run 'resmon' first to bootstrap")
    return
  end

  if not resmonWebview then
    local screen = hs.screen.mainScreen()
    local f = screen:frame()
    local w, h = 1450, 1000
    resmonWebview = hs.webview.new(
      { x = f.x + (f.w - w) / 2, y = f.y + (f.h - h) / 2, w = w, h = h }
    )
    resmonWebview:windowStyle({ "borderless", "closable", "resizable" })
    resmonWebview:level(hs.drawing.windowLevels.floating)
    resmonWebview:alpha(0.85)
    resmonWebview:allowTextEntry(true)
    resmonWebview:windowCallback(function(action)
      if action == "closing" then
        resmonVisible = false
        resmonWebview = nil
      end
    end)
  end

  resmonWebview:url("file://" .. reportPath)
  resmonWebview:show()
  resmonWebview:bringToFront()
  resmonVisible = true
end

hs.hotkey.bind(mod, "m", toggleResmon)

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

-- Cycle the Screen Tutor widget around the screen corners (Cmd+Ctrl+Shift+H).
hs.hotkey.bind({ "cmd", "ctrl", "shift" }, "h", cycleScreenTutorCorner)

--------------------------------------------------------------------------------
-- Help panel (Cmd+Ctrl+/) and command palette (Cmd+Ctrl+P)
--------------------------------------------------------------------------------

-- Human-readable names for the scratchpad hotkeys, keyed by scratchpad name so
-- the scratchpads table above stays untouched. Standalone (non-scratchpad)
-- utility hotkeys live in EXTRA_SHORTCUTS.
local SCRATCHPAD_LABELS = {
  terminal = "Terminal", cadtutor = "CAD Tutor", screentutor = "Screen Tutor",
  joplin = "Joplin", calendar = "Calendar", ranger = "Ranger (files)",
  trello = "Trello", claude = "Claude", calculator = "Calculator (qalc)",
  browser = "Chrome (research)", draw = "LibreOffice Draw", slack = "Slack",
  editor = "VS Code", forks = "Claude forks (tmux)", aiyolo = "AI YOLO",
  daybook = "Daybook",
}

local EXTRA_SHORTCUTS = {
  { keys = "⌘⌃M", label = "Resource Monitor" },
  { keys = "⌘⌃D", label = "Toggle Claude Code diff tabs" },
  { keys = "⌘⌃⇧H", label = "Cycle Screen Tutor corner" },
  { keys = "⌘⌃/", label = "This help panel" },
  { keys = "⌘⌃P", label = "Command palette — search shortcuts & utilities" },
}

-- Every bound hotkey as { keys, label }, sorted for display. Scratchpad rows are
-- generated from the live config, so new scratchpads appear here automatically.
local function shortcutRows()
  local rows = {}
  for name, cfg in pairs(scratchpads) do
    local label = SCRATCHPAD_LABELS[name]
    if label then
      table.insert(rows, { keys = "⌘⌃" .. string.upper(cfg.key), label = label })
    end
  end
  for _, e in ipairs(EXTRA_SHORTCUTS) do
    table.insert(rows, e)
  end
  table.sort(rows, function(a, b) return a.keys < b.keys end)
  return rows
end

-- Where this repo's utility scripts are installed. ~/bin is the flattened,
-- machine-relevant merge of src/utils/<layer>/**, organised into category
-- subdirs (video, fs, os, git, …); prefer it over /usr/local/bin.
local function utilsRoot()
  local home = os.getenv("HOME")
  for _, p in ipairs({ home .. "/bin", "/usr/local/bin" }) do
    if hs.fs.attributes(p, "mode") == "directory" then return p end
  end
  return nil
end

-- First real comment line of a script, used as its one-line description.
local function firstCommentLine(path)
  local f = io.open(path, "r")
  if not f then return "" end
  local desc, n = "", 0
  for line in f:lines() do
    n = n + 1
    if n > 15 then break end
    local body = line:match("^%s*#+%s*(.+)$")
      or line:match("^%s*%-%-+%s*(.+)$")
      or line:match("^%s*//+%s*(.+)$")
    if body and body:sub(1, 1) ~= "!" and #body > 2 then
      desc = body
      break
    end
  end
  f:close()
  if #desc > 90 then desc = desc:sub(1, 88) .. "…" end
  return desc
end

local UTIL_SKIP = {
  ["__init__.py"] = true, ["README.md"] = true, [".keep"] = true,
  ["package.json"] = true, ["github-markdown.css"] = true,
}
local UTIL_EXT = { sh = true, py = true, js = true }

-- Recursively collect scripts under a category dir (depth-capped at 2).
local function collectUtils(dir, category, out, depth)
  if depth > 2 then return end
  for file in hs.fs.dir(dir) do
    local full = dir .. "/" .. file
    local mode = hs.fs.attributes(full, "mode")
    if file:sub(1, 1) ~= "." then
      if mode == "directory" then
        collectUtils(full, category or file, out, depth + 1)
      elseif mode == "file" and not UTIL_SKIP[file]
          and UTIL_EXT[file:match("%.([%w]+)$") or ""] then
        table.insert(out, {
          category = category or "general", name = file,
          path = full, desc = firstCommentLine(full),
        })
      end
    end
  end
end

-- Scan (once, cached) the installed utility scripts, grouped by category.
local utilCache = nil
local function scanUtilities()
  if utilCache then return utilCache end
  local root, out = utilsRoot(), {}
  if root then
    for entry in hs.fs.dir(root) do
      local full = root .. "/" .. entry
      if entry:sub(1, 1) ~= "." and hs.fs.attributes(full, "mode") == "directory" then
        collectUtils(full, entry, out, 1)
      end
    end
  end
  table.sort(out, function(a, b)
    if a.category == b.category then return a.name < b.name end
    return a.category < b.category
  end)
  utilCache = out
  return out
end

local function htmlEscape(s)
  return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function buildHelpHtml()
  local p = {}
  table.insert(p, [[<!DOCTYPE html><html><head><meta charset="utf-8"><style>
    body{font-family:-apple-system,Menlo,monospace;background:#1e1e2e;color:#cdd6f4;margin:0;padding:24px;font-size:14px}
    h1{font-size:18px;margin:0 0 4px;color:#89b4fa}
    h2{font-size:14px;margin:22px 0 8px;color:#f9e2af;border-bottom:1px solid #45475a;padding-bottom:4px}
    h3{font-size:11px;margin:14px 0 4px;color:#a6e3a1;text-transform:uppercase;letter-spacing:.06em}
    .sc{display:grid;grid-template-columns:repeat(2,1fr);gap:5px 24px}
    .row{display:flex;gap:10px;align-items:baseline}
    kbd{background:#313244;border:1px solid #45475a;border-radius:4px;padding:1px 7px;font-size:12px;min-width:52px;text-align:center;color:#f5c2e7;flex:none}
    .util{font-size:12px;margin:2px 0}
    .un{color:#89dceb}
    .ud{color:#7f849c}
    .hint{color:#6c7086;font-size:11px;margin-top:22px;text-align:center}
  </style></head><body>]])
  table.insert(p, "<h1>⌨︎ Workstation Help</h1>")
  table.insert(p, "<h2>Keyboard shortcuts</h2><div class='sc'>")
  for _, r in ipairs(shortcutRows()) do
    table.insert(p, string.format(
      "<div class='row'><kbd>%s</kbd><span>%s</span></div>",
      htmlEscape(r.keys), htmlEscape(r.label)))
  end
  table.insert(p, "</div>")
  table.insert(p, "<h2>Utilities <span class='ud'>(~/bin — search &amp; open with ⌘⌃P)</span></h2>")
  local lastCat = nil
  for _, u in ipairs(scanUtilities()) do
    if u.category ~= lastCat then
      table.insert(p, "<h3>" .. htmlEscape(u.category) .. "</h3>")
      lastCat = u.category
    end
    local line = "<span class='un'>" .. htmlEscape(u.name) .. "</span>"
    if u.desc ~= "" then
      line = line .. " <span class='ud'>— " .. htmlEscape(u.desc) .. "</span>"
    end
    table.insert(p, "<div class='util'>" .. line .. "</div>")
  end
  table.insert(p, "<div class='hint'>⌘⌃/ to dismiss · ⌘⌃P to search &amp; open a utility</div>")
  table.insert(p, "</body></html>")
  return table.concat(p, "\n")
end

local helpWebview, helpVisible = nil, false

local function toggleHelp()
  if helpVisible and helpWebview then
    helpWebview:hide()
    helpVisible = false
    return
  end
  if not helpWebview then
    local f = hs.screen.mainScreen():frame()
    local w = 920
    local h = math.min(f.h - 80, 1040)
    helpWebview = hs.webview.new(
      { x = f.x + (f.w - w) / 2, y = f.y + (f.h - h) / 2, w = w, h = h }
    )
    helpWebview:windowStyle({ "borderless", "closable", "resizable" })
    helpWebview:level(hs.drawing.windowLevels.floating)
    helpWebview:alpha(0.96)
    helpWebview:allowTextEntry(true)
    helpWebview:windowCallback(function(action)
      if action == "closing" then
        helpVisible = false
        helpWebview = nil
      end
    end)
  end
  helpWebview:html(buildHelpHtml())
  helpWebview:show()
  helpWebview:bringToFront()
  helpVisible = true
end

local function openUtility(path)
  hs.execute("open -a 'Visual Studio Code' '" .. path .. "'", true)
end

local function paletteChoices()
  local choices = {}
  for _, r in ipairs(shortcutRows()) do
    table.insert(choices, { text = r.label, subText = "shortcut · " .. r.keys, kind = "shortcut" })
  end
  for _, u in ipairs(scanUtilities()) do
    local sub = u.category
    if u.desc ~= "" then sub = sub .. " · " .. u.desc end
    table.insert(choices, { text = u.name, subText = sub, kind = "util", path = u.path })
  end
  return choices
end

local paletteChooser = nil

local function showPalette()
  if not paletteChooser then
    paletteChooser = hs.chooser.new(function(choice)
      if not choice then return end
      if choice.kind == "util" and choice.path then
        openUtility(choice.path)
      elseif choice.kind == "shortcut" then
        hs.alert.show(choice.text .. "  ·  " .. (choice.subText or ""))
      end
    end)
    paletteChooser:placeholderText("Search shortcuts & utilities…")
    paletteChooser:searchSubText(true)
  end
  paletteChooser:choices(paletteChoices())
  paletteChooser:show()
end

hs.hotkey.bind(mod, "/", toggleHelp)
hs.hotkey.bind(mod, "p", showPalette)

-- Optional Hammerspoon extensions (the screen-tutor highlight overlay, staged
-- from the macOS layer). Absent on machines without the file; pcall keeps init
-- robust either way.
pcall(dofile, os.getenv("HOME") .. "/.hammerspoon/screen_tutor.lua")

hs.alert.show("Hammerspoon config loaded")
