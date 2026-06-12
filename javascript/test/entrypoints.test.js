import { test, describe } from 'node:test';
import { strict as assert } from 'node:assert';

import { extractUrls as pslUrls, Extractor as PslExtractor } from '../src/index.js';
import { extractUrls as ianaUrls, Extractor as IanaExtractor } from '../src/index-iana.js';
import { Extractor as CoreExtractor, makeHostChecker } from '../src/core.js';

describe('public-suffix tiers', () => {
  test('default (PSL) and /iana both tell a real TLD from a bogus one', () => {
    for (const fn of [pslUrls, ianaUrls]) {
      const x = fn('see blogspot.jp and blogspot.exe');
      assert.deepEqual(x, ['https://blogspot.jp']);
    }
  });

  test('both reject a typo TLD', () => {
    assert.deepEqual(pslUrls('mail example.cmo please'), []);
    assert.deepEqual(ianaUrls('mail example.cmo please'), []);
  });

  test('both accept an IDN TLD', () => {
    assert.deepEqual(pslUrls('see 普遍适用测试.我爱你 ok'), ['https://普遍适用测试.我爱你']);
    assert.deepEqual(ianaUrls('see 普遍适用测试.我爱你 ok'), ['https://普遍适用测试.我爱你']);
  });

  test('the pre-wired Extractor of each entry validates like its functions', () => {
    assert.equal(new PslExtractor().extractUrls('a blogspot.exe b').length, 0);
    assert.equal(new IanaExtractor().extractUrls('a blogspot.exe b').length, 0);
  });
});

describe('uts58/core', () => {
  test('with no table, accepts any host that clears the syntax rules', () => {
    const ex = new CoreExtractor();
    assert.deepEqual(ex.extractUrls('see blogspot.exe'), ['https://blogspot.exe']);
    // a bare TLD has nothing registrable in front
    assert.equal(ex.extractUrls('see com here').length, 0);
  });

  test('honours an injected checker built from a suffix set', () => {
    const ex = new CoreExtractor({ isPlausibleHost: makeHostChecker(new Set(['com'])) });
    assert.deepEqual(ex.extractUrls('a.com b.jp c.exe'), ['https://a.com']);
  });

  test('a checker requires a label in front of the suffix', () => {
    const check = makeHostChecker(new Set(['co.uk', 'uk']));
    assert.equal(check('bbc.co.uk'), true);
    assert.equal(check('co.uk'), true);   // co is in front of uk
    assert.equal(check('uk'), false);     // nothing in front
  });
});
