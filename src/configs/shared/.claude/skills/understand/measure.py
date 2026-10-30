import re, subprocess, os, sys

src_path = sys.argv[1] if len(sys.argv) > 1 else 'infographic.html'
src = open(src_path).read()
probe = """
<script>
window.addEventListener('load', function () {
  var out = [];
  document.querySelectorAll('.page').forEach(function (p, i) {
    out.push((i + 1) + ':' + Math.round(p.getBoundingClientRect().height));
  });
  document.title = 'H|' + out.join(' ');
});
</script>
"""
# A4 portrait minus 12mm margins top/bottom -> content box in CSS px at 96dpi
width_px = round((210 - 22) / 25.4 * 96)
limit_px = round((297 - 24) / 25.4 * 96)

meas = src.replace('</head>', probe + '</head>')
meas = meas.replace('<body>', f'<body style="width:{width_px}px">')
open('measure.html', 'w').write(meas)

chrome = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
r = subprocess.run([chrome, '--headless', '--disable-gpu', '--virtual-time-budget=3000',
                    '--dump-dom', f'file://{os.getcwd()}/measure.html'],
                   capture_output=True, text=True)
m = re.search(r'<title>H\|([^<]*)</title>', r.stdout)
print(f'content width {width_px}px · page limit {limit_px}px\n')
if not m:
    print('no measurement captured'); raise SystemExit(1)
for pair in m.group(1).split():
    n, h = pair.split(':')
    h = int(h)
    flag = 'OVERFLOW' if h > limit_px else 'ok'
    print(f'  page {n}: {h:>5}px   {flag}   ({h - limit_px:+}px)')
