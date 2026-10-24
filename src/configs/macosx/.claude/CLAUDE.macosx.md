# macOS — Machine-Local Instructions

## Screen Tutor skill

`screen-tutor` (`/screen-tutor` in Claude Code, `$screen-tutor` in Codex) is a
general-purpose on-screen assistant. When the user asks, it captures a screenshot of the
current app, analyzes it, and highlights the applicable control. It shows the highlight as
a live overlay or in the annotated file `~/screen-tutor.png`. It captures the screen
**only when the user asks**. It does not capture the screen automatically. If it can
answer from local data, it does that first, before it uses tokens on a screenshot.

- Engine: `~/bin/screen-tutor/screen_tutor.py`. The `vision_ocr.swift` file in the same
  directory gives an Apple Vision OCR fallback.
- Live overlay: `screen_tutor.py highlight --box "x,y,w,h:label"` draws a glowing box
  over the real button through Hammerspoon (`~/.hammerspoon/screen_tutor.lua`). The box
  fades automatically.
- Pad: **Cmd+Ctrl+H** opens and closes the Screen Tutor terminal. The terminal starts the
  skill immediately. It uses the harness (Claude or Codex) that is selected at
  *Tutor harness* in the Cmd+Ctrl+/ help panel. A change to this setting applies to the
  next pad that you open.

On the M4 CAD workstation, `cad-tutor` is a CAD-specific version of this skill. It uses
the same `screen_tutor.py` engine and `screenHighlight` overlay.
