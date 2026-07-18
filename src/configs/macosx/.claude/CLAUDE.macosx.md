# macOS — Machine-Local Instructions

## Screen Tutor skill

`screen-tutor` (`/screen-tutor` in Claude Code, `$screen-tutor` in Codex) is a
general-purpose on-screen assistant: on request it screenshots whatever app you're in,
reasons about it, and highlights the relevant control (live overlay or annotated
`~/screen-tutor.png`). It captures **only when you ask** — never on its own, and
prefers answering locally before spending tokens on a screenshot.

- Engine: `~/bin/screen-tutor/screen_tutor.py` (with `vision_ocr.swift` Apple Vision
  OCR fallback alongside it).
- Live overlay: `screen_tutor.py highlight --box "x,y,w,h:label"` draws a glowing box
  over the real button via Hammerspoon (`~/.hammerspoon/screen_tutor.lua`), auto-fading.

On the M4 CAD workstation, `cad-tutor` is a CAD-specific specialization built on this
same `screen_tutor.py` engine + `screenHighlight` overlay.
