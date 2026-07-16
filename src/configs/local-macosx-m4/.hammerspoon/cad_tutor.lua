-- ~/.hammerspoon/cad_tutor.lua  (macm4 only)
--
-- Live on-screen highlight overlays for the `cad-tutor` skill. Loaded by the
-- shared init.lua via `pcall(dofile, ...)`, so it is a safe no-op on machines
-- where this file is absent.
--
-- Globals exposed for the `hs -c` CLI driven by ~/bin/cad-tutor/cad_tutor.py:
--   cadHighlight(x, y, w, h, label, duration)  -- box + label at screen POINTS
--   cadHighlightClear()                        -- remove every active overlay
--
-- Coordinates are screen points (top-left origin, global space). cad_tutor.py
-- converts screenshot pixels -> points using the sidecar geometry from `shot`.

local overlays = {}
local ACCENT = { red = 1, green = 0.36, blue = 0, alpha = 1 }

function cadHighlightClear()
  for _, canvas in ipairs(overlays) do
    canvas:delete()
  end
  overlays = {}
end

local function boxCanvas(x, y, w, h)
  local pad = 6
  local canvas = hs.canvas.new({ x = x - pad, y = y - pad, w = w + 2 * pad, h = h + 2 * pad })
  canvas:appendElements({
    type = "rectangle",
    action = "stroke",
    strokeColor = ACCENT,
    strokeWidth = 4,
    roundedRectRadii = { xRadius = 8, yRadius = 8 },
  })
  return canvas
end

local function labelCanvas(x, y, text)
  local width = math.max(64, #text * 9 + 16)
  local height = 22
  local canvas = hs.canvas.new({ x = x, y = y - height - 4, w = width, h = height })
  canvas:appendElements(
    {
      type = "rectangle",
      action = "fill",
      fillColor = { black = 1, alpha = 0.8 },
      roundedRectRadii = { xRadius = 5, yRadius = 5 },
    },
    {
      type = "text",
      text = text,
      textColor = { white = 1 },
      textSize = 14,
      frame = { x = 8, y = 2, w = width - 12, h = height - 4 },
    }
  )
  return canvas
end

local function present(canvas)
  canvas:level(hs.canvas.windowLevels.overlay)
  canvas:clickActivating(false)
  canvas:canvasMouseEvents(false, false, false, false)
  canvas:show()
  overlays[#overlays + 1] = canvas
end

function cadHighlight(x, y, w, h, label, duration)
  duration = duration or 5
  present(boxCanvas(x, y, w, h))
  if label and label ~= "" then
    present(labelCanvas(x, y, label))
  end
  if duration > 0 then
    hs.timer.doAfter(duration, cadHighlightClear)
  end
end
