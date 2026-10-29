// Types for 'uts58/core' — the extractor with no public-suffix table.

import type {
  UrlEntity, EmailEntity, Entity, ExtractUrlsOptions,
} from './index.js';

export {
  Extractor,
  type ExtractorOptions,
  type ExtractUrlsOptions,
  type UrlEntity,
  type EmailEntity,
  type Entity,
  type Indices,
} from './index.js';

/** The six convenience wrappers bound to one extractor. */
export interface Api {
  extractUrlsWithIndices(text: string, options?: ExtractUrlsOptions): UrlEntity[];
  extractUrls(text: string, options?: ExtractUrlsOptions): string[];
  extractEmailAddressesWithIndices(text: string): EmailEntity[];
  extractEmailAddresses(text: string): string[];
  extractEntitiesWithIndices(text: string, options?: ExtractUrlsOptions): Entity[];
  extractEntities(text: string, options?: ExtractUrlsOptions): string[];
}

/** Build a host-plausibility predicate over a flat set of public suffixes
 * (lower-cased, A-label folded). A host passes when some trailing run of its
 * labels is in the set and at least one label sits in front of it. */
export declare function makeHostChecker(
  suffixes: Set<string>,
): (host: string) => boolean;

/** Build the six convenience functions over a shared extractor instance. */
export declare function makeApi(shared: import('./index.js').Extractor): Api;
