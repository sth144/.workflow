# Skill: Playwright Screenshot to Joplin

## When to Use

Use this skill when you need to capture browser screenshots via the Playwright MCP server and embed them in Joplin notes. Trigger phrases include: "screenshot to Joplin", "capture and embed", "attach screenshot to note", "screenshot for the daybook".

## Prerequisites

- **Playwright MCP server** must be connected with an active browser page
- **Joplin MCP server** must be connected (provides note CRUD)
- **Joplin REST API** must be accessible at `http://localhost:41184` (Joplin desktop app running)
- **Joplin API token**: Read from `.claude.json` MCP config under `joplin → env → JOPLIN_TOKEN`

## Parameters

- **filename**: Descriptive kebab-case name for the screenshot (e.g., `login-page-verified.png`)
- **note_id**: Joplin note ID to embed the screenshot in (optional — can create a new note)
- **element_ref**: Playwright snapshot ref to screenshot a specific element (optional — defaults to viewport)
- **full_page**: Whether to capture the full scrollable page (default: false)

## Instructions

### Step 1: Take the Screenshot with Playwright

Use the Playwright MCP `browser_take_screenshot` tool. The filename must be a **relative path** — Playwright restricts output to the `.playwright-mcp/` directory and the working directory.

```
mcp__playwright__browser_take_screenshot(
  type: "png",
  filename: "my-screenshot.png"
)
```

For a specific element (requires a snapshot ref):

```
mcp__playwright__browser_take_screenshot(
  type: "png",
  filename: "my-element.png",
  element: "Login form",
  ref: "e42"
)
```

For full-page capture:

```
mcp__playwright__browser_take_screenshot(
  type: "png",
  filename: "full-page.png",
  fullPage: true
)
```

### Step 2: Locate the Saved File

Screenshots are saved relative to the current working directory. Verify the file exists:

```bash
ls -la /path/to/working/dir/my-screenshot.png
```

### Step 3: Compress if Needed

If the screenshot exceeds a size threshold (default: 500KB), convert it from PNG to JPEG to reduce upload size. This uses Python with Pillow, which works on both macOS and Linux:

```bash
python3 -c "
import os, sys
filepath = sys.argv[1]
threshold = int(sys.argv[2])
quality = int(sys.argv[3])
size = os.path.getsize(filepath)
if size <= threshold:
    print(f'Size {size}B is under threshold ({threshold}B), skipping compression')
    sys.exit(0)
try:
    from PIL import Image
except ImportError:
    print('Pillow not installed, skipping compression')
    sys.exit(0)
img = Image.open(filepath)
if img.mode in ('RGBA', 'P'):
    img = img.convert('RGB')
out = filepath.rsplit('.', 1)[0] + '.jpg'
img.save(out, 'JPEG', quality=quality, optimize=True)
old_size = size
new_size = os.path.getsize(out)
print(f'Compressed {old_size}B -> {new_size}B ({100 - new_size * 100 // old_size}% reduction)')
os.remove(filepath)
os.rename(out, filepath.rsplit('.', 1)[0] + '.jpg')
" /path/to/my-screenshot.png 512000 80
```

**Notes:**
- The threshold (512000 = 500KB) and quality (80) are tunable. Lower quality = smaller file.
- RGBA/transparent PNGs are converted to RGB (white background implied by JPEG).
- If Pillow is not installed, compression is skipped gracefully.
- After compression the file extension changes to `.jpg` — update the filename used in subsequent steps accordingly.
- To install Pillow if missing: `pip install Pillow` (or `apt install python3-pil` on Debian/Ubuntu).

### Step 4: Read the Joplin API Token

Extract the token from the MCP configuration:

```bash
python3 -c "
import json
with open('$HOME/.claude.json') as f:
    cfg = json.load(f)
token = cfg.get('mcpServers', {}).get('joplin', {}).get('env', {}).get('JOPLIN_TOKEN', '')
print(token)
"
```

Or search `.claude.json` with Grep for `JOPLIN_TOKEN`.

### Step 5: Upload the Screenshot as a Joplin Resource

Use the Joplin REST API to create a resource (attachment):

```bash
JOPLIN_TOKEN="<token>"
curl -s -X POST "http://localhost:41184/resources?token=$JOPLIN_TOKEN" \
  -F "data=@/path/to/my-screenshot.png" \
  -F 'props={"title": "my-screenshot.png", "filename": "my-screenshot.png"}'
```

Parse the resource ID from the JSON response:

```bash
RESOURCE_ID=$(curl -s -X POST "http://localhost:41184/resources?token=$JOPLIN_TOKEN" \
  -F "data=@/path/to/screenshot.png" \
  -F 'props={"title": "screenshot.png", "filename": "screenshot.png"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
```

### Step 6: Embed in a Joplin Note

Reference the uploaded resource in Markdown using Joplin's internal link syntax:

```markdown
![Description of screenshot](:/RESOURCE_ID)
```

Use the Joplin MCP `update_note` tool to append or insert the image reference into the note body.

### Step 7: Clean Up

Remove the screenshot file from the working directory so it doesn't get committed to git:

```bash
rm -f /path/to/my-screenshot.png
```

## Batch Upload Pattern

When uploading multiple screenshots, use a loop:

```bash
JOPLIN_TOKEN="<token>"
BASE="/path/to/working/dir"

for f in 01-login.png 02-dashboard.png 03-results.png; do
  RESULT=$(curl -s -X POST "http://localhost:41184/resources?token=$JOPLIN_TOKEN" \
    -F "data=@${BASE}/${f}" \
    -F "props={\"title\": \"${f}\", \"filename\": \"${f}\"}")
  ID=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null)
  echo "${f} -> ${ID}"
done
```

Then build the Markdown with the collected IDs:

```markdown
![Login page](:/abc123)
![Dashboard](:/def456)
![Results](:/ghi789)
```

## Error Handling

- **Playwright file access denied**: Screenshots must use relative paths within the allowed roots (`.playwright-mcp/` or working directory). Don't use `/tmp/` or absolute paths outside the project.
- **Joplin REST API unreachable**: Verify Joplin desktop app is running. Check `http://localhost:41184/ping?token=TOKEN`.
- **Resource upload fails**: Check the token is correct and the file exists. The API returns a JSON object with `id` on success, or an error message.
- **Image not rendering in Joplin**: Ensure the syntax is exactly `![alt](:/RESOURCE_ID)` — the `:/` prefix is required.

## Safety

- Always clean up screenshot files from the repo directory after uploading
- Never commit screenshot PNGs to git (check with `git status` after cleanup)
- The Joplin API token is sensitive — don't log it or include it in note content
