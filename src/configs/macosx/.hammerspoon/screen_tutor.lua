-- ~/.hammerspoon/screen_tutor.lua  (macOS layer)
--
-- Live on-screen highlight overlays for the `screen-tutor` / `cad-tutor` skills.
-- Loaded by the shared init.lua via `pcall(dofile, ...)`, so it is a safe no-op
-- on machines where this file is absent.
--
-- Globals exposed for the `hs -c` CLI driven by ~/bin/screen-tutor/screen_tutor.py:
--   screenHighlight(x, y, w, h, label, duration)  -- box + label at screen POINTS
--   screenHighlightClear()                        -- remove every active overlay
--
-- Coordinates are screen points (top-left origin, global space). screen_tutor.py
-- converts screenshot pixels -> points using the sidecar geometry from `shot`.

local overlays = {}
local ACCENT = { red = 1, green = 0.36, blue = 0, alpha = 1 }

function screenHighlightClear()
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

function screenHighlight(x, y, w, h, label, duration)
  duration = duration or 5
  present(boxCanvas(x, y, w, h))
  if label and label ~= "" then
    present(labelCanvas(x, y, label))
  end
  if duration > 0 then
    hs.timer.doAfter(duration, screenHighlightClear)
  end
end

-- ---------------------------------------------------------------------------
-- Accessibility targeting: find on-screen controls by their text and return
-- exact screen-point frames, so the tutor can highlight "the Save button"
-- without a screenshot or coordinate guessing. Fully local (no model tokens).
-- ---------------------------------------------------------------------------

local AX_TEXT_ATTRS = { "AXTitle", "AXDescription", "AXValue", "AXHelp", "AXLabel" }

local function axText(el)
  for _, attr in ipairs(AX_TEXT_ATTRS) do
    local ok, v = pcall(function() return el:attributeValue(attr) end)
    if ok and type(v) == "string" and v ~= "" then
      return v
    end
  end
  return nil
end

local function axFrame(el)
  local pos = el:attributeValue("AXPosition")
  local size = el:attributeValue("AXSize")
  if pos and size and size.w and size.h then
    return { x = pos.x, y = pos.y, w = size.w, h = size.h, label = axText(el) }
  end
  return nil
end

local function axSearch(el, needle, out, depth, budget)
  if depth <= 0 or #out >= 20 or budget.n <= 0 then
    return
  end
  budget.n = budget.n - 1
  local text = axText(el)
  if text and string.find(string.lower(text), needle, 1, true) then
    local f = axFrame(el)
    if f and f.w > 0 and f.h > 0 then
      out[#out + 1] = f
    end
  end
  local kids = el:attributeValue("AXChildren")
  if type(kids) == "table" then
    for _, kid in ipairs(kids) do
      axSearch(kid, needle, out, depth - 1, budget)
    end
  end
end

-- Print a JSON array of {x,y,w,h,label} (screen points) for controls whose text
-- contains `query` (case-insensitive) in `appName` (or the frontmost app).
function screenLocate(appName, query)
  local app = (appName ~= "" and hs.application.get(appName))
    or hs.application.frontmostApplication()
  local axapp = app and hs.axuielement.applicationElement(app)
  if not axapp then
    print("[]")
    return
  end
  local out = {}
  axSearch(axapp, string.lower(query), out, 16, { n = 6000 })
  local parts = {}
  for _, m in ipairs(out) do
    local label = string.gsub(m.label or "", '["\\%c]', " ")
    parts[#parts + 1] = string.format(
      '{"x":%.1f,"y":%.1f,"w":%.1f,"h":%.1f,"label":"%s"}',
      m.x, m.y, m.w, m.h, label)
  end
  print("[" .. table.concat(parts, ",") .. "]")
end

-- Backward-compatible aliases (cad-tutor shipped these names first).
cadHighlight = screenHighlight
cadHighlightClear = screenHighlightClear
