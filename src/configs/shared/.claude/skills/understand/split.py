import re, sys

src_path = sys.argv[2] if len(sys.argv) > 2 else 'infographic.html'
src = open(src_path).read()
head = src.split('<body>')[0]
pages = re.findall(
    r'<!-- =+ PAGE (\d) =+ -->\s*(<div class="page">.*?</div>)\s*(?=<!-- =+ PAGE|</body>)',
    src, re.S)
want = sys.argv[1]
body = [b for n, b in pages if n == want][0]
open(f'p{want}.html', 'w').write(head + '<body style="width:760px;padding:10px">' + body + '</body></html>')
print(f'wrote p{want}.html  ({len(body)} chars)')
