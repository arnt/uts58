import { test, describe } from 'node:test';
import { strict as assert } from 'node:assert';
import {
  Extractor,
  extractUrls,
  extractUrlsWithIndices,
  extractEmailAddresses,
  extractEmailAddressesWithIndices,
  extractEntities,
  extractEntitiesWithIndices,
} from '../src/index.js';

const extractor = new Extractor();
const extract = (text) => extractor.extractUrlsWithIndices(text);

test('rejects an invalid domain', () => {
  assert.equal(extract('a test.x b').length, 0);
  // tldts (like Ruby's PublicSuffix) considers .invalid a TLD, but
  // the extractor rejects it explicitly.
  assert.equal(extract('a test.invalid b').length, 0);
});

test('accepts blogspot.com as a domain', () => {
  assert.equal(extract('a blogspot.com b').length, 1);
});

test('does not regard .com alone as a domain', () => {
  assert.equal(extract('a com b').length, 0);
});

test('handles ports sensibly', () => {
  const x = extract('a example.com:443 b');
  assert.equal(x.length, 1);
  assert.deepEqual(x[0].indices, [2, 17]);
});

test('includes a path', () => {
  const x = extract('a example.com/123 b');
  assert.equal(x.length, 1);
  assert.deepEqual(x[0].indices, [2, 17]);
});

test('includes a query', () => {
  const x = extract('a example.com?123 b');
  assert.equal(x.length, 1);
  assert.deepEqual(x[0].indices, [2, 17]);
});

test('includes a fragment', () => {
  const x = extract('a example.com#123 b');
  assert.equal(x.length, 1);
  assert.deepEqual(x[0].indices, [2, 17]);
});

test('includes a giant long thing', () => {
  const x = extract('a example.com/123?123#123 b');
  assert.equal(x.length, 1);
  assert.deepEqual(x[0].indices, [2, 25]);
});

test('finishes before trailing parens', () => {
  let x = extract('a (example.com/123?123#123) b');
  assert.deepEqual(x[0].indices, [3, 26]);
  x = extract('a (example.com/123?123#(123)) b');
  assert.deepEqual(x[0].indices, [3, 28]);
});

test('is clever about full stops', () => {
  let x = extract('a example.com/123.html b');
  assert.deepEqual(x[0].indices, [2, 22]);
  x = extract('a example.com/123. HTML is great');
  assert.deepEqual(x[0].indices, [2, 17]);
  x = extract('a example.com/123... HTML is so great');
  assert.deepEqual(x[0].indices, [2, 17]);
  x = extract('a example.com/123.');
  assert.deepEqual(x[0].indices, [2, 17]);
});

test('decodes A-labels in the resulting URL', () => {
  const x = extract('xn-----ctdbabcfhu9c2b9l1acccr4c.xn--mgbah1a3hjkrd');
  assert.equal(x.length, 1);
  assert.equal(x[0].url, 'https://تجربة-القبول-الشامل.موريتانيا');
});

const uasg004domains = [
  'universal-acceptance-test.international',
  'universal-acceptance-test.icu',
  'تجربة-القبول-الشامل.موريتانيا',
  'համընդհանուր-ընկալում-թեստ.հայ',
  'সর্বজনীন-স্বীকৃতির-পরীক্ষা.ভারত',
  'универсальное-принятие-тест.москва',
  'सार्वभौमिक-स्वीकृति-परीक्षण.संगठन',
  'უნივერსალური-თავსობადობის-ტესტი.გე',
  'καθολική-αποδοχή-δοκιμή.ευ',
  'સાર્વત્રિક-સ્વીકૃતિ-પરીક્ષણ.ભારત',
  'ਸਰਵਵਿਆਪਕ-ਪ੍ਰਵਾਨਗੀ-ਪਰਖ.ਭਾਰਤ',
  '다국어도메인이용환경테스트.한국',
  'מבחן-קבלה-אוניברסלי.קום',
  'どこでもつかえる.みんな',
  'ಸಾರ್ವತ್ರಿಕ-ಸ್ವೀಕಾರಾರ್ಹತೆ-ಪರೀಕ್ಷೆ.ಭಾರತ',
  'ユニバーサルアクセプタンス.クラウド',
  'ສາກົນ-ການຍອມຮັບ-ທົດລອງ.ລາວ',
  'സാർവത്രിക-സ്വീകാര്യതാ-പരിശോധന.ഭാരതം',
  'ଯୁନିଭରସାଲ-ଏକସେପ୍ଟନ୍ସ-ଟେଷ୍ଟ.ଭାରତ',
  'විශ්ව-සම්මුති-පිරික්සුම.ලංකා',
  'பொது-ஏற்பு-சோதனை.சிங்கப்பூர்',
  'యూనివర్సల్-ఆమోదం-పరీక్ష.భారత్',
  'ยูเอทดสอบ.ไทย',
  '普遍适用测试.我爱你',
  '普遍適用測試.台灣',
  'ሁለንአቀፍ-ተቀባይነት-ሙከራ.com',
  'ការសាកល្បងទទួលយកជាអន្តរជាតិ.com',
  'အလုံးစုံလက်ခံမှုစမ်းသပ်ချက်.com',
  'ދުނިޔެ-ގަބޫލުކުރާ-ޓެސްޓު.com',
  'universal-acceptance-test.קום',
  'épreuve-acceptation-universelle.org',
];
for (const url of uasg004domains) {
  test(`picks UASG004 domain ${url}`, () => {
    const x = extract(`Lorem ipsum ${url} dolor sit amet`);
    assert.equal(x.length, 1);
    assert.equal(x[0].url, `https://${url}`);
  });
}

test('picks Tibetan UASG004 test out of text', () => {
  const x = extract('Lorem ipsum ཡོངས་ཁྱབ་ངོས་ལེན་བརྟག་དཔྱད.com dolor sit amet');
  assert.ok(x.map((y) => y.url).includes('https://ཡོངས་ཁྱབ་ངོས་ལེན་བརྟག་དཔྱད.com'));
});

const uasg004misc = [
  'Universales-Akzeptanz-Test.vermögensberatung',
  'épreuve-acceptation-universelle.org',
  '普遍适用测试。我爱你',
  'تجربة-القبول-الشامل.xn--mgbah1a3hjkrd',
  'xn-----ctdbabcfhu9c2b9l1acccr4c.xn--mgbah1a3hjkrd',
  'universal-acceptance-test.icu/测试',
  '普遍适用测试.我爱你/测试',
  'تجربة-القبول-الشامل.موريتانيا/تجربة',
];
for (const url of uasg004misc) {
  test(`picks UASG004 misc ${url}`, () => {
    const x = extract(`Lorem ipsum ${url} dolor sit amet`);
    assert.equal(x.length, 1);
  });
}

test('picks a plain domain', () => {
  assert.equal(extract('Lorem ipsum example.com dolor sit amet').length, 1);
});

test('picks Wikipedia articles with parens in the path', () => {
  assert.equal(
    extract('blah en.wikipedia.org/wiki/The_Lovemakers_(film) blah').length,
    1,
  );
});

test('keeps bracketed query parameters in the URL', () => {
  assert.equal(
    extract('blah example.com/?foo[1]=a&amp;foo[2]=b blah')[0].url,
    'https://example.com/?foo[1]=a&amp;foo[2]=b',
  );
});

for (const url of [
  'comoyo.com/play/S(123)',
  'example.com/knutsen_ludvigsen/ver(k)ste(d)/brilleslange.mp3',
  'example.com/Bob_Marley/Rastaman_Vibration/11_Jah_Live_(originally_issued_as_Island_Single_(WIP_6265))_(bonus_track)',
]) {
  test(`handles complicated song player URL ${url}`, () => {
    assert.equal(extract(`Lorem ipsum ${url} dolor sit amet`)[0].url, `https://${url}`);
  });
}

const railsAutolink = [
  'business.timesonline.co.uk/article/0,,9065-2473189,00.html',
  'www.mail-archive.com/ruby-talk@ruby-lang.org/',
  'tools.ietf.org/html/rfc3986',
  'www.amazon.com/Testing-Equal-Sign-In-Path/ref=pd_bbs_sr_1?ie=UTF8&s=books&qid=1198861734&sr=8-1',
  'www.google.com/doku.php?id=gps:resource:scs:start',
  'maps.google.co.uk/maps?f=q&q=the+london+eye&ie=UTF8&ll=51.503373,-0.11939&spn=0.007052,0.012767&z=16&iwloc=A',
  'www.rubyonrails.com/foo.cgi?trailing_hyphen=value-',
  'www.rubyonrails.com/foo.cgi?trailing_forward_slash=value/',
];
for (const url of railsAutolink) {
  for (const u of [url, `https://${url}`]) {
    test(`picks ${u}`, () => {
      assert.equal(extract(`blah ${u} blah`)[0].url, `https://${url}`);
    });
  }
}

test('is not led astray by a LONG link', () => {
  const long = 'example.'.repeat(100000) + 'com';
  assert.equal(extract(`blah ${long} blah`).length, 0);
});

test('handles empty input', () => {
  assert.equal(extract('').length, 0);
});

test('finds two non-overlapping URLs in one string', () => {
  const x = extract('a blogspot.com b example.com c');
  assert.equal(x.length, 2);
  assert.deepEqual(x.map((r) => r.url), [
    'https://blogspot.com',
    'https://example.com',
  ]);
});

test('does not detect a second link inside an embedded URL', () => {
  const url = 'https://archive.org/20260225/https://example.com/example';
  const x = extract(`foo ${url} bar`);
  assert.equal(x.length, 1);
  assert.equal(x[0].url, url);
});

for (const u of [
  'ftp://ftp.archaic.example.com',
  'ssh://server.example.com',
  'sftp://files.example.com',
  'ldap://directory.example.com',
]) {
  test(`does not linkify host inside unsupported scheme ${u}`, () => {
    assert.equal(extract(`foo ${u} bar`).length, 0);
  });
}

test('preserves http:// when the input has it', () => {
  const x = extract('foo http://example.com bar');
  assert.equal(x.length, 1);
  assert.equal(x[0].url, 'http://example.com');
});

// A classic userinfo-confusable, beloved by some phishers: a browser
// parses https://www.bbc.co.uk@npmjs.com/something as host=npmjs.com
// with userinfo www.bbc.co.uk. Linkifying it as one href would carry
// the reader to npmjs.com even if the user clicks the middle 'b' in
// bbc.

// We extract the two as separate links, destroying the deception. if
// the user looks in the direction of bbc and clicks, the browser goes
// to the bbc, fi the user looks in the direction of npnjs, the
// browser goes to npmjs.
test('splits a userinfo-style phishing link into two real ones', () => {
  const x = extractUrlsWithIndices(
    'mumble  https://www.bbc.co.uk@npmjs.com/something stumble',
  );
  assert.deepEqual(x, [
    { url: 'https://www.bbc.co.uk', indices: [8, 29] },
    { url: 'https://npmjs.com/something', indices: [30, 49] },
  ]);
});

test('rejects port 0', () => {
  assert.equal(extract('a example.com:0 b').length, 0);
});

test('rejects ports above 65535', () => {
  assert.equal(extract('a example.com:100000 b').length, 0);
});

test('accepts low and mid-range ports', () => {
  assert.equal(extract('a example.com:1 b').length, 1);
  assert.equal(extract('a example.com:1000 b').length, 1);
  assert.equal(extract('a example.com:65535 b').length, 1);
});

test('terminates at a surplus closing bracket', () => {
  const x = extract('a example.com/foo) b');
  assert.equal(x.length, 1);
  assert.equal(x[0].url, 'https://example.com/foo');
});

test('terminates at a mismatched closing bracket', () => {
  const x = extract('a example.com/foo(bar] b');
  assert.equal(x.length, 1);
  assert.equal(x[0].url, 'https://example.com/foo(bar');
});

test('finds an http:// link directly preceded by non-Latin letters', () => {
  const x = extract('テストhttp://example.com/日本語');
  assert.equal(x.length, 1);
  assert.equal(x[0].url, 'http://example.com/日本語');
  assert.deepEqual(x[0].indices, [3, 25]);
});

test('keeps the path when the input ends with one', () => {
  const x = extract('Visit https://example.com/example');
  assert.equal(x.length, 1);
  assert.equal(x[0].url, 'https://example.com/example');
});

test('treats surrounding square brackets as terminators', () => {
  const x = extract('a [example.com/path] b');
  assert.equal(x.length, 1);
  assert.equal(x[0].url, 'https://example.com/path');
});

describe('Extractor#extractUrls', () => {
  test('returns only the URL strings', () => {
    assert.deepEqual(
      extractor.extractUrls('a blogspot.com b example.com c'),
      ['https://blogspot.com', 'https://example.com'],
    );
  });
});

describe('Extractor#maxLength', () => {
  test('defaults to null so nothing is filtered out', () => {
    const e = new Extractor();
    assert.equal(e.maxLength, null);
    assert.equal(e.extractUrls('foo example.com bar').length, 1);
  });

  test('drops matches whose input span exceeds the limit', () => {
    const e = new Extractor();
    e.maxLength = 10;
    assert.deepEqual(e.extractUrls('foo example.com bar'), []);
  });

  test('keeps matches whose input span equals the limit', () => {
    const e = new Extractor();
    e.maxLength = 'example.com'.length;
    assert.deepEqual(e.extractUrls('foo example.com bar'), ['https://example.com']);
  });

  test('measures the input span, not the returned URL', () => {
    const e = new Extractor();
    e.maxLength = 11;
    assert.deepEqual(e.extractUrls('foo example.com bar'), ['https://example.com']);
  });

  test('still drops a scheme-bearing match whose input span exceeds the limit', () => {
    const e = new Extractor();
    e.maxLength = 15;
    assert.deepEqual(e.extractUrls('foo https://example.com bar'), []);
  });

  test('filters per-match, keeping shorter ones in a mixed input', () => {
    const e = new Extractor();
    e.maxLength = 12;
    assert.deepEqual(
      e.extractUrls('see blogspot.com and universal-acceptance-test.icu please'),
      ['https://blogspot.com'],
    );
  });
});

describe('Extractor#removeOverlappingEntities', () => {
  test('drops later entries that start inside an earlier span', () => {
    const entities = [
      { url: 'a', indices: [0, 10] },
      { url: 'b', indices: [5, 15] },
      { url: 'c', indices: [10, 20] },
      { url: 'd', indices: [12, 18] },
    ];
    assert.deepEqual(
      extractor.removeOverlappingEntities(entities).map((e) => e.url),
      ['a', 'c'],
    );
  });

  test('is a no-op on an empty or already-disjoint list', () => {
    assert.deepEqual(extractor.removeOverlappingEntities([]), []);
    const disjoint = [
      { url: 'a', indices: [0, 5] },
      { url: 'b', indices: [10, 15] },
    ];
    assert.deepEqual(extractor.removeOverlappingEntities(disjoint), disjoint);
  });
});

describe('Extractor#extractEmailAddressesWithIndices', () => {
  const extractEmails = (text) => extractor.extractEmailAddressesWithIndices(text);

  test('extracts a plain ASCII address', () => {
    const x = extractEmails('Contact abcd@example.com');
    assert.equal(x.length, 1);
    assert.equal(x[0].email, 'abcd@example.com');
    assert.equal(x[0].url, 'mailto:abcd@example.com');
    assert.deepEqual(x[0].indices, [8, 24]);
  });

  test('includes a medial dot in the local-part', () => {
    const x = extractEmails('Contact x.abcd@example.com');
    assert.equal(x.length, 1);
    assert.equal(x[0].email, 'x.abcd@example.com');
  });

  test('accepts a non-ASCII local-part', () => {
    const x = extractEmails('Contact አርበርቶ.አርበርቶ@example.com');
    assert.equal(x.length, 1);
    assert.equal(x[0].email, 'አርበርቶ.አርበርቶ@example.com');
  });

  test('accepts the Greek example from UTS #58 §5.1', () => {
    const x = extractEmails('write to σωκράτης@example.com');
    assert.equal(x.length, 1);
    assert.equal(x[0].email, 'σωκράτης@example.com');
  });

  test('handles a mix of ASCII/non-ASCII combinations', () => {
    for (const addr of [
      'grå@grå.org',
      'info@grå.org',
      'arnt@grå.org',
      '阿Q@例子.中国',
      '例子@例子.中国',
      'उदाहरण@उदाहरण.भारत',
      'gøril@example.com',
    ]) {
      const x = extractEmails(`hi ${addr} there`);
      assert.equal(x.length, 1, `expected to extract ${addr}`);
      assert.equal(x[0].email, addr);
    }
  });

  test('rejects an address with no valid domain', () => {
    assert.equal(extractEmails('Contact x@example.😎').length, 0);
  });

  test('rejects an address with no local-part', () => {
    assert.equal(extractEmails('Contact @example.com').length, 0);
  });

  test('rejects a local-part that ends with a dot', () => {
    assert.equal(extractEmails('Contact john.@example.com').length, 0);
  });

  test('rejects a local-part with consecutive dots', () => {
    assert.equal(extractEmails('Contact john..doe@example.com').length, 0);
  });

  test('rejects a local-part that starts with a dot', () => {
    assert.equal(extractEmails('Contact .john.doe@example.com').length, 0);
  });

  test('absorbs a leading mailto: into the span', () => {
    const x = extractEmails('see mailto:abcd@example.com please');
    assert.equal(x.length, 1);
    assert.equal(x[0].email, 'abcd@example.com');
    assert.equal(x[0].url, 'mailto:abcd@example.com');
    assert.deepEqual(x[0].indices, [4, 27]);
  });

  test('absorbs a mailto: only at a clean boundary', () => {
    const x = extractEmails('foomailto:abcd@example.com');
    assert.equal(x.length, 1);
    assert.equal(x[0].email, 'abcd@example.com');
  });

  test('decodes A-labels in the domain', () => {
    const x = extractEmails('write to arnt@xn-----ctdbabcfhu9c2b9l1acccr4c.xn--mgbah1a3hjkrd');
    assert.equal(x.length, 1);
    assert.equal(x[0].email, 'arnt@تجربة-القبول-الشامل.موريتانيا');
  });

  test('finds two addresses in one text', () => {
    const x = extractEmails('from arnt@grå.org to gøril@example.com today');
    assert.deepEqual(x.map((r) => r.email), ['arnt@grå.org', 'gøril@example.com']);
  });

  test('rejects a bare @ with no local-part or domain', () => {
    assert.equal(extractEmails('a @ b').length, 0);
  });

  test('respects maxLength', () => {
    const e = new Extractor();
    e.maxLength = 10;
    assert.deepEqual(e.extractEmailAddresses('see abcd@example.com'), []);
    e.maxLength = 'abcd@example.com'.length;
    assert.deepEqual(e.extractEmailAddresses('see abcd@example.com'), ['abcd@example.com']);
  });
});

describe('module-level email wrappers', () => {
  test('exposes extractEmailAddressesWithIndices', () => {
    assert.equal(
      extractEmailAddressesWithIndices('write arnt@grå.org now')[0].email,
      'arnt@grå.org',
    );
  });

  test('exposes extractEmailAddresses', () => {
    assert.deepEqual(extractEmailAddresses('write arnt@grå.org now'), ['arnt@grå.org']);
  });
});

describe('module-level combined entity wrappers', () => {
  test('returns both urls and email addresses', () => {
    const x = extractEntitiesWithIndices('mail arnt@grå.org or see blogspot.com');
    assert.equal(x.length, 2);
    assert.equal(x[0].email, 'arnt@grå.org');
    assert.equal(x[0].url, 'mailto:arnt@grå.org');
    assert.equal(x[1].url, 'https://blogspot.com');
  });

  test('keeps the email and drops the bare domain when they overlap', () => {
    const x = extractEntitiesWithIndices('contact info@grå.org today');
    assert.equal(x.length, 1);
    assert.equal(x[0].email, 'info@grå.org');
  });

  test('sorts entities by start offset', () => {
    const x = extractEntitiesWithIndices('see blogspot.com then mail gøril@example.com');
    assert.deepEqual(x.map((e) => e.url), [
      'https://blogspot.com',
      'mailto:gøril@example.com',
    ]);
  });

  test('flattens to mailto/https url strings via extractEntities', () => {
    assert.deepEqual(extractEntities('mail arnt@grå.org or see blogspot.com'), [
      'mailto:arnt@grå.org',
      'https://blogspot.com',
    ]);
  });

  test('returns an empty list for text with neither', () => {
    assert.deepEqual(extractEntitiesWithIndices('nothing to see here'), []);
    assert.deepEqual(extractEntities('nothing to see here'), []);
  });
});

describe('module-level wrappers', () => {
  test('exposes extractUrlsWithIndices', () => {
    assert.equal(
      extractUrlsWithIndices('see example.com here')[0].url,
      'https://example.com',
    );
  });

  test('exposes extractUrls', () => {
    assert.deepEqual(extractUrls('see example.com here'), ['https://example.com']);
  });

  // The Tibetan tseg (U+0F0B) acts as a label separator, so the raw
  // extractor returns the full domain plus several shorter suffixes
  // that start partway through it. The earliest-starting candidate —
  // which here is also the longest — is the one that survives.
  test('strips overlapping candidates, keeping the earliest-starting one', () => {
    const tibetan = 'ཡོངས་ཁྱབ་ངོས་ལེན་བརྟག་དཔྱད.com';
    const text = `Lorem ipsum ${tibetan} dolor sit amet`;
    const raw = new Extractor().extractUrlsWithIndices(text);
    assert.ok(raw.length > 1);
    const wrapped = extractUrlsWithIndices(text);
    assert.equal(wrapped.length, 1);
    assert.equal(wrapped[0].url, `https://${tibetan}`);
  });
});
