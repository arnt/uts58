// Type declarations for uts58 (the default and /iana entries; /core has its
// own core.d.ts). Hand-written to match the sources; keep them in sync by
// hand (there's no build step).

/** A `[start, end)` span, measured in Unicode codepoints — not UTF-16 code
 * units. To slice the source text by these, index `Array.from(text)`, not
 * the string directly, or astral characters will throw the offsets off. */
export type Indices = [start: number, end: number];

/** A web link found in the text. `url` carries the IDN-decoded host and a
 * scheme (`https://` is prepended when the input had none). */
export interface UrlEntity {
  url: string;
  indices: Indices;
}

/** An email address found in the text. `email` is the bare address;
 * `url` is the same address as a `mailto:` URL, so the result drops into
 * anything that already renders a `url` entity. Both carry the IDN-decoded
 * domain. */
export interface EmailEntity {
  email: string;
  url: string;
  indices: Indices;
}

/** Either kind of entity, as returned by the combined extractors. Narrow on
 * the presence of `email` to tell them apart. */
export type Entity = UrlEntity | EmailEntity;

export interface ExtractorOptions {
  /** Decides whether a candidate hostname is real enough to linkify — the
   * public-suffix check. The default and /iana entries inject one; on /core
   * it defaults to accepting any host that clears the shape rules. */
  isPlausibleHost?: (host: string) => boolean;
}

/** The underlying extractor. The module-level functions wrap a shared
 * instance; construct your own to set `maxLength`, swap the host check, or
 * get the raw, possibly-overlapping list before merging with other
 * extractors. */
export declare class Extractor {
  constructor(options?: ExtractorOptions);

  /** Maximum length of a matched span, in input codepoints. `null` (the
   * default) means no limit. Candidates longer than this are dropped. */
  maxLength: number | null;

  isPlausibleHost: (host: string) => boolean;

  extractUrlsWithIndices(text: string): UrlEntity[];
  extractUrls(text: string): string[];
  extractEmailAddressesWithIndices(text: string): EmailEntity[];
  extractEmailAddresses(text: string): string[];

  /** Drops every entity whose span overlaps an earlier one. Stable; the
   * earlier-starting entity wins. Does not mutate the input. */
  removeOverlappingEntities<T extends { indices: Indices }>(entities: T[]): T[];
}

export declare function extractUrlsWithIndices(text: string): UrlEntity[];
export declare function extractUrls(text: string): string[];
export declare function extractEmailAddressesWithIndices(text: string): EmailEntity[];
export declare function extractEmailAddresses(text: string): string[];

/** Both URLs and email addresses, sorted by start offset with overlaps
 * removed — an email beats the bare domain that sits inside it after the
 * `@`. Email addresses appear in their `mailto:` form under `url`. */
export declare function extractEntitiesWithIndices(text: string): Entity[];
export declare function extractEntities(text: string): string[];
