# macm4 — Machine-Local Instructions

## CAD / 3D Project Storage

Blender and FreeCAD are installed on this machine. Each app has an MCP server (`blender`,
`freecad`). When you create or save CAD or 3D project files, save them to the CAD archive
on `sthinds.local` (the Ubuntu box). This machine mounts the archive over SMB:

- **Blender** projects → `~/Drive/D/Documents/CAD/Blender/` (default). If the share is
  not available, use the local backup directory `~/Documents/CAD/Blender/`.
- **FreeCAD** projects → `~/media/.mounts/D/Documents/CAD/FreeCAD/`

On `sthinds.local`, these paths are in the `D` Samba share: `Documents/CAD/Blender` and
`Documents/CAD/FreeCAD`. `~/Drive/D` is a symlink to the same mount
(`~/media/.mounts/D`). Its name is easier to use.

Rules:
- Save Blender projects directly to `~/Drive/D/Documents/CAD/Blender/` while you work. Do
  not use a local working copy in `~/blender-projects/`. If the share is not mounted or
  not available, save to the local backup directory `~/Documents/CAD/Blender/`. When the
  share is available again, copy the file to the share.
- For FreeCAD, keep a working copy on the local disk while you do the work. When the work
  is complete, copy the `.FCStd` file to the CAD archive.
- Save `.blend` files as self-contained files (pack the external data). Then each file
  opens without other files.
- When you control Blender or FreeCAD through MCP, render the preview frames to
  `~/blender-preview.png`. The pinned VS Code image tab then shows them live.
- `uvx blender-mcp` and `uvx freecad-mcp` must run as **arm64-native** processes. The MCP
  configuration sets `--python 3.12` and `UV_PYTHON_PREFERENCE=only-managed`. Do not
  start them from a Rosetta/x86_64 shell. If you do, the arm64 `pydantic_core` wheel does
  not agree with the shell architecture, and the server stops.
- Start the bridge in the app before you control the app:
  - Blender → *BlenderMCP* sidebar tab → *Connect*
  - FreeCAD → *MCP Addon* workbench → *Start RPC Server*
- **Token cost and screenshots**: Each `execute_code` or `get_view` call in `freecad-mcp`
  returns a large base64 PNG (25k or more tokens). This size can truncate the tool
  result. In long modeling sessions with many iterations, these images cause most of the
  cost. You can use two methods to decrease the cost:
  - Add `--only-text-feedback` to the freecad-mcp `args`. This stops all returned images
    and decreases the cost a lot. But you cannot see the model. Use this method only if
    you can verify the result in a different way (for example, `print()` of object
    counts, `BoundBox`, or calculated dimensions), or if the user describes the result to
    you.
  - Middle method (the default for tasks that must match a visual reference): Keep the
    images on. During iterations, use `print()` in `execute_code` to verify. Get a render
    (with a small `width`/`height`) only at milestones, not after each edit.

## GIS / QGIS

QGIS is installed on this machine with an MCP server (`qgis`). It has the same two-part
architecture as Blender and FreeCAD. `qgis-mcp` is a fork of BlenderMCP. A plugin opens a
socket server *in* QGIS, and the stdio MCP server sends the commands to it.

- **Start the bridge before you control QGIS:** QGIS → *QGIS MCP* dock widget →
  *Start Server*. The server listens on `localhost:9876`. If a tool call shows
  "connection refused", the dock server is not running. Tell the user, and continue. Do
  not try the call again and again without a change.
- **Version lockstep.** The part in the app is the *QGIS MCP* plugin (Plugins → Manage
  and Install Plugins). It needs QGIS 3.28 or later. The server part is pinned to git tag
  `v0.7.1` in `mcp.macm4.json`, because that is the plugin version on plugins.qgis.org. A
  newer server can send commands that an older plugin cannot process. Thus, **update the
  two parts together**: update the plugin first, then move the pinned tag.
- **Tool mode.** `QGIS_MCP_TOOL_MODE=compound` is set. This mode shows approximately 23
  grouped tools (`project`, `layer`, `features`, `style`, `canvas`, `render`,
  `processing`, `code`, `layer_tree`, `expression`, `transform`, …) instead of
  approximately 102 granular tools. Remove the environment variable only if you need a
  granular tool that no group contains.
- **Token cost and renders.** `render` and map-canvas calls return base64 PNGs. This is
  the same problem as in freecad-mcp. During iterations, use `print()` through the `code`
  group to verify layer counts, extents, CRS, and feature counts. Get a render with a
  small `width` only at milestones.
- **`execute_code` runs arbitrary PyQGIS** in the live app. Give it the same trust level
  as `execute_blender_code`. It can overwrite project files and layers on the disk. Thus,
  if a typed tool is available, use the typed tool.
- **Optional hardening.** By default, the socket accepts only localhost connections and
  has no authentication. Each local process that can connect to the port can control
  QGIS. To require a shared secret, set `QGIS_MCP_TOKEN` in *both* the QGIS process
  environment and the `env` block of the server. Note: if you start QGIS from Finder, it
  does not get the variables that the shell exports. In that case, use `launchctl setenv`
  or start QGIS from a shell.

Save `.qgz` / `.qgs` projects to the GIS archive on `sthinds.local`. This is the same
convention as the CAD archive: `~/media/.mounts/D/Documents/GIS/` (the `D` Samba share →
`Documents/GIS`). Also keep the layer sources on the share, or use absolute paths that
resolve on the mount. By default, QGIS stores relative layer paths. If you move a project
off the mount, its layers do not open.

## CAD Tutor skill

`cad-tutor` is the CAD-specific version of the general-purpose `screen-tutor` skill (the
macOS layer documents that skill). It uses the same `screen_tutor.py` engine and
`screenHighlight` overlay.

To help the user in a live CAD session, use the `cad-tutor` skill (`/cad-tutor` in Claude
Code, `$cad-tutor` in Codex). The skill has its own scratchpad window: the **CAD Tutor**
terminal. This terminal is at the top-right, away from the viewport. **Cmd+Ctrl+G** opens
and closes it. The pad starts the skill immediately. It uses the harness (Claude or
Codex) that is selected at *Tutor harness* in the Cmd+Ctrl+/ help panel. A change to this
setting applies to the next pad that you open.

The skill examines the model through the `blender`/`freecad` MCP servers. It captures a
screenshot of the app window (`~/bin/screen-tutor/screen_tutor.py shot`). It highlights
the applicable control in two ways:
- **Live overlay** — `screen_tutor.py highlight --box "x,y,w,h:label"` draws a glowing
  box over the real button through Hammerspoon (`~/.hammerspoon/screen_tutor.lua`). The
  box fades automatically.
- **Annotated screenshot** — `screen_tutor.py annotate …` writes `~/cad-tutor.png`. Pin
  this file as a VS Code image tab.
