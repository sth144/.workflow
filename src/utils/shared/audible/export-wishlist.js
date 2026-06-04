(async () => {
  const PAGE_SIZE = 50;
  const BASE = '/library/wishlist';
  const all = new Map();

  for (let page = 1; ; page++) {
    console.log(`Fetching page ${page}...`);

    const resp = await fetch(`${BASE}?pageSize=${PAGE_SIZE}&page=${page}`, {
      credentials: 'include'
    });

    const html = await resp.text();
    const doc = new DOMParser().parseFromString(html, 'text/html');

    const rows = [...doc.querySelectorAll('li.bc-list-item')]
      .filter(el => el.innerText.includes('Remove from Wish List'));

    let newCount = 0;

    for (const el of rows) {
      const lines = el.innerText.split('\n').map(s => s.trim()).filter(Boolean);

      const book = {
        title: lines[0] || '',
        subtitle: lines[1] || '',
        author: lines.find(x => x.startsWith('By:'))?.replace(/^By:\s*/, '') || '',
        narrator: lines.find(x => x.startsWith('Narrated by:'))?.replace(/^Narrated by:\s*/, '') || '',
        series: lines.find(x => x.startsWith('Series:'))?.replace(/^Series:\s*/, '') || '',
        length: lines.find(x => x.startsWith('Length:'))?.replace(/^Length:\s*/, '') || '',
        releaseDate: lines.find(x => x.startsWith('Release date:'))?.replace(/^Release date:\s*/, '') || ''
      };

      const key = `${book.title}__${book.author}`;
      if (!all.has(key)) {
        all.set(key, book);
        newCount++;
      }
    }

    console.log(`Found ${rows.length}; new ${newCount}; total ${all.size}`);

    if (rows.length === 0 || newCount === 0) break;
  }

  const books = [...all.values()];

  const csv = [
    ['Title','Subtitle','Author','Narrator','Series','Length','Release date'],
    ...books.map(b => [b.title,b.subtitle,b.author,b.narrator,b.series,b.length,b.releaseDate])
  ].map(row => row.map(v => `"${String(v).replaceAll('"','""')}"`).join(',')).join('\n');

  const a = document.createElement('a');
  a.href = URL.createObjectURL(new Blob([csv], { type: 'text/csv' }));
  a.download = 'audible-wishlist.csv';
  a.click();
})();