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
