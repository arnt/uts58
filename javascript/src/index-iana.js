// 'uts58/iana': same API as the default entry, but hosts are checked only
// against the IANA root-zone TLD list (~5 KB gz vs ~27 KB for the PSL). The
// rightmost label must be a real TLD; that distinguishes blogspot.jp from
// blogspot.exe and rejects typos like example.cmo, while accepting a bare
// co.uk / kawasaki.jp as plausible. The smallest sensible table for the
// browser.

import { Extractor as CoreExtractor } from './extractor.js';
import { isPlausibleHost } from './tlds-iana.js';
import { makeApi } from './api.js';

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
