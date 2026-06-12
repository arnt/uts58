// Default entry point: UTS #58 web-link extraction, with hosts validated
// against the Public Suffix List (ICANN section). The six functions are thin
// wrappers around a shared Extractor; they also drop overlapping candidates,
// keeping the earlier-starting one.
//
//   import { extractUrls, extractUrlsWithIndices } from 'uts58';
//   extractUrls("see example.com here")              // ["https://example.com"]
//   extractUrlsWithIndices("see example.com here")   // [{ url: "https://example.com", indices: [4, 15] }]
//
// For a smaller table import 'uts58/iana' (root-zone TLDs only); to bring
// your own validator (e.g. tldts) import { Extractor } from 'uts58/core'.

import { Extractor as CoreExtractor } from './extractor.js';
import { isPlausibleHost } from './suffixes-psl.js';
import { makeApi } from './api.js';

// Extractor pre-wired with the PSL check, so `new Extractor()` from this
// entry validates the same way the module-level functions do.
export class Extractor extends CoreExtractor {
  constructor(options = {}) {
    super({ isPlausibleHost, ...options });
  }
}

const _shared = new Extractor();

export const {
  extractUrlsWithIndices,
  extractUrls,
  extractEmailAddressesWithIndices,
  extractEmailAddresses,
  extractEntitiesWithIndices,
  extractEntities,
} = makeApi(_shared);
