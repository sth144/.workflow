# macm4 — Machine-Local Instructions

## CAD / 3D Project Storage

Blender and FreeCAD are set up on this machine with MCP servers (`blender`, `freecad`).
When you create or save CAD / 3D project files, save them to the CAD archive on
`sthinds.local` (the Ubuntu box), which is mounted locally over SMB:

- **Blender** projects → `~/media/.mounts/D/Documents/CAD/Blender/`
- **FreeCAD** projects → `~/media/.mounts/D/Documents/CAD/FreeCAD/`

(On `sthinds.local` these are the `D` Samba share → `Documents/CAD/Blender` and
`Documents/CAD/FreeCAD`.)

Guidelines:
- Keep an in-progress working copy under `~/blender-projects/` while iterating, then copy
  the finished `.blend` / `.FCStd` to the CAD archive above.
- Save `.blend` files self-contained (pack external data) so they open standalone.
- When driving Blender/FreeCAD via MCP, render preview frames to `~/blender-preview.png`
  so they show up live in the pinned VS Code image tab.
- `uvx blender-mcp` / `uvx freecad-mcp` must run **arm64-native** (the MCP config pins
  `--python 3.12` + `UV_PYTHON_PREFERENCE=only-managed`). Never launch them from a
  Rosetta/x86_64 shell, or the arm64 `pydantic_core` wheel mismatch will crash the server.
- Start the in-app bridge before driving: Blender → *BlenderMCP* sidebar tab → *Connect*;
  FreeCAD → *MCP Addon* workbench → *Start RPC Server*.
- **Token cost / screenshots**: `freecad-mcp`'s `execute_code`/`get_view` return a large
  base64 PNG each (~25k+ tokens, enough to truncate the tool result). For long iterative
  modeling sessions this dominates cost. Two levers:
  - Add `--only-text-feedback` to the freecad-mcp `args` (below) to suppress all returned
    images — big savings, but you go blind, so only use it when you can verify by other
    means (e.g. `print()` object counts / `BoundBox` / computed dimensions) or when the
    user is describing the result to you.
  - Middle path (default for visual-matching tasks): keep images on, but verify with
    `print()` in `execute_code` during iteration and only pull a render (small
    `width`/`height`) at milestones instead of after every edit.

## GIS / QGIS

QGIS is set up on this machine with an MCP server (`qgis`). Same two-part architecture as
Blender/FreeCAD — `qgis-mcp` is a fork of BlenderMCP: a plugin opens a socket server
*inside* QGIS, and the stdio MCP server relays to it.

- **Start the bridge before driving:** QGIS → *QGIS MCP* dock widget → *Start Server*
  (listens on `localhost:9876`). If a tool call reports a connection refused, the dock
  server isn't running — say so and continue rather than retrying blind.
- **Version lockstep.** The in-app half is the *QGIS MCP* plugin (Plugins → Manage and
  Install Plugins, needs QGIS ≥ 3.28); the server half is pinned to git tag `v0.7.1` in
  `mcp.macm4.json` because that's the plugin version on plugins.qgis.org. A newer server
  can send commands an older plugin has no handler for, so **bump both together** — update
  the plugin, then move the pinned tag.
- **Tool mode.** `QGIS_MCP_TOOL_MODE=compound` is set, which exposes ~23 grouped tools
  (`project`, `layer`, `features`, `style`, `canvas`, `render`, `processing`, `code`,
  `layer_tree`, `expression`, `transform`, …) instead of ~102 granular ones. Drop the env
  var only if you need a granular tool that no group covers.
- **Token cost / renders.** `render`/map-canvas calls return base64 PNGs, the same
  freecad-mcp trap described above. Verify with `print()` of layer counts / extents /
  CRS / feature counts via the `code` group during iteration, and pull a small-`width`
  render only at milestones.
- **`execute_code` runs arbitrary PyQGIS** in the live app — same trust posture as
  `execute_blender_code`. It can overwrite project files and layers on disk, so prefer
  the typed tools when one exists.
- **Optional hardening.** The socket is localhost-only with no auth by default; any local
  process that reaches the port can drive QGIS. To require a shared secret, set
  `QGIS_MCP_TOKEN` in *both* QGIS's own process environment and the server's `env` block —
  note that QGIS launched from Finder won't inherit a shell export, so it needs
  `launchctl setenv` or a shell launch.

Save `.qgz` / `.qgs` projects to the GIS archive on `sthinds.local`, mirroring the CAD
archive convention: `~/media/.mounts/D/Documents/GIS/` (the `D` Samba share →
`Documents/GIS`). Keep layer sources on the share too, or use absolute paths that resolve
on the mount — QGIS stores relative layer paths by default and a project moved off the
mount will open with broken layers.

## CAD Tutor skill

`cad-tutor` is the CAD-specific specialization of the general-purpose `screen-tutor`
skill (documented at the macOS layer), built on the same `screen_tutor.py` engine +
`screenHighlight` overlay.

For hands-on help in a live CAD session, invoke the `cad-tutor` skill (`/cad-tutor`
in Claude Code, `$cad-tutor` in Codex). It has its own scratchpad window — toggle
the **CAD Tutor** terminal (top-right, clear of the viewport) with **Cmd+Ctrl+G**.
It inspects the model via the `blender`/`freecad` MCP servers, screenshots the app
window (`~/bin/screen-tutor/screen_tutor.py shot`), and highlights the relevant control
two ways:
- **Live overlay** — `screen_tutor.py highlight --box "x,y,w,h:label"` draws a glowing
  box over the real button via Hammerspoon (`~/.hammerspoon/screen_tutor.lua`), auto-fading.
- **Annotated screenshot** — `screen_tutor.py annotate …` writes `~/cad-tutor.png`
  (pin it as a VS Code image tab).
