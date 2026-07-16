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

## CAD Tutor skill

For hands-on help in a live CAD session, invoke the `cad-tutor` skill (`/cad-tutor`
in Claude Code, `$cad-tutor` in Codex). It has its own scratchpad window — toggle
the **CAD Tutor** terminal (top-right, clear of the viewport) with **Cmd+Ctrl+G**.
It inspects the model via the `blender`/`freecad` MCP servers, screenshots the app
window (`~/bin/cad-tutor/cad_tutor.py shot`), and highlights the relevant control
two ways:
- **Live overlay** — `cad_tutor.py highlight --box "x,y,w,h:label"` draws a glowing
  box over the real button via Hammerspoon (`~/.hammerspoon/cad_tutor.lua`), auto-fading.
- **Annotated screenshot** — `cad_tutor.py annotate …` writes `~/cad-tutor.png`
  (pin it as a VS Code image tab).
