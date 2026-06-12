// 'uts58/core': the extractor with no public-suffix table bundled. Bring
// your own host validator: either build one over a suffix set with
// makeHostChecker, or wrap a library you already depend on:
//
//   import { Extractor } from 'uts58/core';
//   import { parse } from 'tldts';
//   const ex = new Extractor({
//     isPlausibleHost: (h) => {
//       const p = parse(h);
//       return !!p.domain && p.isIcann && p.publicSuffix !== 'invalid';
//     },
//   });
//   ex.extractUrls('see example.com here');
//
// With no `isPlausibleHost`, any host that clears the syntax rules (≥2
// labels, length, etc.) is accepted. This is useful when some later stage
// does the real validation, perhaps using an actual DNS lookup.

export { Extractor } from './extractor.js';
export { makeHostChecker } from './plausible.js';
export { makeApi } from './api.js';
