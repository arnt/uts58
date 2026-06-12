// JavaScript port of the Ruby `Uts58::Extractor`. UTS58 link
// extraction; see https://github.com/arnt/uts58 Ruby
// implementation. Behavioural notes that differ from the Ruby are
// flagged inline; everything else is meant to match.

import punycode from 'punycode/punycode.js';
import {
  OPENERS,
  TERMINATION_KIND,
  terminationKind,
} from './constants.js';

const PATH_CLOSERS = new Set([0x23, 0x2f, 0x3f]); // # / ?
const QUERY_CLOSERS = new Set([0x23]);            // #
const FRAGMENT_CLOSERS = new Set();

// The Ruby `\p{Alnum}` class is letters + numbers only; JS doesn't
// ship that as a single property escape, so we spell it out.
const ALNUM = '\\p{L}\\p{N}';
const LNM = '\\p{L}\\p{N}\\p{M}';
const SEP_EXTRAS = '\\u00DF\\u03C2\\u06FD\\u06FE\\u0F0B\\u3007';

const TRIGGER_RE = new RegExp(
  `(?<![-${ALNUM}\\p{M}.\\/])(?=[${ALNUM}][-${LNM}${SEP_EXTRAS}]*[.:。])`,
  'gu',
);

const SCHEME_RE = new RegExp(
  '^([\\p{Script=Han}\\p{Script=Hiragana}\\p{Script=Katakana}\\p{Script=Hangul}\\p{Script=Thai}\\p{Script=Lao}\\p{Script=Khmer}\\p{Script=Myanmar}]*?)(https?:\\/\\/)',
  'iu',
);

const PREFIX_RE = new RegExp(
  `^(?:[-${LNM}${SEP_EXTRAS}]+[.。]){1,4}[-${LNM}]+(?![-${LNM}])`,
  'u',
);

const PORT_RE = /^:(\d+)/;

// The widest slice we ever hand to an anchored host/scheme match. A host is
// rejected past 254 cp and a scheme is tiny, so nothing legitimate reaches
// this limit. This protects the server against malevolent input.
const MAX_HOST_SCAN_CP = 262;

// One local-part character. We walk left from an '@' testing this rather
// than slicing the whole preceding text and matching it anchored, which was
// O(prefix) per '@'. XID_Continue covers the letters/digits/marks UTS #58
// allows; the punctuation set is the dot-atom-plus-extras from the spec.
const LP_CHAR = new RegExp("[\\p{XID_Continue}.!#$%&'*+\\-/=?^_`{|}~]", 'u');

// RFC5321 caps a local-part at 64 octets. If a candidate is longer,
// we reject the whole candidate, rather than assume that some suffix
// is an address.
const MAX_LOCALPART_CP = 64;

// Convert a UTF-16 string into an array of codepoint strings, so the
// rest of the pipeline can index by codepoint exactly like the Ruby
// version. Each element holds one full codepoint (1 or 2 UTF-16
// units).
function toCodepoints(s) {
  return Array.from(s);
}

function cpSlice(cps, start, end) {
  return cps.slice(start, end).join('');
}

// Returns true if a soft terminator at position i is followed only by
// more soft terminators and then a hard one (or end of input). Used
// to decide whether trailing punctuation belongs to the URL or to the
// surrounding prose.
function followedByHard(cps, i) {
  let j = i;
  while (j < cps.length) {
    const k = terminationKind(cps[j].codePointAt(0));
    if (k !== TERMINATION_KIND.soft) break;
    j++;
  }
  if (j >= cps.length) return true;
  return terminationKind(cps[j].codePointAt(0)) === TERMINATION_KIND.hard;
}

// Walks one path/query/fragment segment, honouring bracket pairing
// and the spec's soft/hard terminator distinction. Returns the
// codepoint index in `cps` at which the segment ends (i.e. the first
// codepoint not consumed); the caller passes that index back in as
// the new `start` for the next segment.
function skipComponent(cps, start, extraClosers) {
  const openers = [];
  for (let i = start; i < cps.length; i++) {
    if (i === start) continue; // the lead-in character (e.g. '/', '?', '#')
    const cp = cps[i].codePointAt(0);
    if (extraClosers.has(cp)) return i;
    const k = terminationKind(cp);
    if (k === -1) continue;
    if (k === TERMINATION_KIND.hard) return i;
    if (k === TERMINATION_KIND.soft) {
      if (followedByHard(cps, i)) return i;
    } else if (k === TERMINATION_KIND.close) {
      const want = OPENERS.get(cp);
      if (openers.length && openers[openers.length - 1] === want) {
        openers.pop();
      } else {
        return i;
      }
    } else if (k === TERMINATION_KIND.open) {
      openers.push(cp);
    }
  }
  return cps.length;
}

// IDN A-label → U-label decoding. punycode.toUnicode does the lookup
// per label, so '.' separation is enough; the caller has already
// translated the ideographic full stop '。' to '.'.
function idnToUnicode(host) {
  try {
    return punycode.toUnicode(host);
  } catch {
    return host;
  }
}

export class Extractor {
  // `isPlausibleHost(host)` decides whether a candidate hostname is
  // real enough to linkify. Most users want to determine this
  // locally, without performing e.g. a DNS lookup, but details
  // vary. This is injected so the table (IANA, PSL, or a tldts-backed
  // predicate the caller provides) is a bundle-time choice; the entry
  // points in index.js / index-iana.js wire in a default.
  //
  // With no predicate, any host that matches earlier checks is
  // accepted, which is the table-free 'core' behaviour.


  constructor({ isPlausibleHost = () => true } = {}) {
    this.isPlausibleHost = isPlausibleHost;
    // Maximum allowed length of the matched text, in input codepoints.
    // null means no limit, matching the Ruby default.
    this.maxLength = null;
  }

  extractUrlsWithIndices(text) {
    const cps = toCodepoints(text);
    const joined = cps.join(''); // identical to text in content, but we
                                 // also need a UTF-16 → codepoint index map.
    // Build a map from UTF-16 offset to codepoint index. cpAt[u] is the
    // number of codepoints starting strictly before UTF-16 offset u.
    const cpAt = new Int32Array(joined.length + 1);
    {
      let cp = 0;
      for (let u = 0; u < joined.length; u++) {
        cpAt[u] = cp;
        const code = joined.charCodeAt(u);
        // a high surrogate consumes two UTF-16 units for one codepoint
        if (code >= 0xd800 && code <= 0xdbff && u + 1 < joined.length) {
          cpAt[u + 1] = cp;
          u++;
        }
        cp++;
      }
      cpAt[joined.length] = cp;
    }

    const result = [];
    TRIGGER_RE.lastIndex = 0;
    let m;
    while ((m = TRIGGER_RE.exec(joined)) !== null) {
      // Zero-width lookahead match: advance lastIndex by one UTF-16
      // unit (or one codepoint) so we don't loop forever.
      const triggerU16 = m.index;
      const triggerCp = cpAt[triggerU16];
      {
        const code = joined.charCodeAt(triggerU16);
        TRIGGER_RE.lastIndex = triggerU16 +
          (code >= 0xd800 && code <= 0xdbff ? 2 : 1);
      }

      // post_match: everything from the trigger onward, as a
      // codepoint-indexed view. We'll work in codepoint indices and
      // build the result substring from `cps`.
      const postStart = triggerCp;

      // Allow letter/mark/number characters between the trigger and a
      // scheme like "http://". post_match string for SCHEME_RE:
      const postStr = cpSlice(cps, postStart,
        Math.min(cps.length, postStart + MAX_HOST_SCAN_CP));
      let schemeOffset = 0; // codepoints between trigger and the actual link start
      let proto = 'https://';
      let prefixStart = postStart;
      const sm = SCHEME_RE.exec(postStr);
      if (sm) {
        schemeOffset = toCodepoints(sm[1]).length;
        proto = sm[2];
        prefixStart = postStart + schemeOffset + toCodepoints(sm[2]).length;
      }

      // Prefix: the candidate hostname.
      const prefixStr = cpSlice(cps, prefixStart,
        Math.min(cps.length, prefixStart + MAX_HOST_SCAN_CP));
      const pm = PREFIX_RE.exec(prefixStr);
      if (!pm) continue;
      const prefixCpLen = toCodepoints(pm[0]).length;
      if (prefixCpLen >= 254) continue;

      const hostRaw = pm[0].replace(/。/g, '.');
      const hn = idnToUnicode(hostRaw);
      if (!this.isPlausibleHost(hn)) continue;

      // Walk the optional port, then any number of path segments,
      // then an optional query, then an optional fragment.
      let i = prefixStart + prefixCpLen;
      const restStr = () => cpSlice(cps, i, Math.min(cps.length, i + 8));

      const pmPort = PORT_RE.exec(restStr());
      if (pmPort) {
        const n = parseInt(pmPort[1], 10);
        if (n < 1 || n > 65535) continue;
        i += pmPort[0].length; // ASCII digits + colon, so length == cp count
      }

      while (cps[i] === '/') i = skipComponent(cps, i, PATH_CLOSERS);
      if (cps[i] === '?') i = skipComponent(cps, i, QUERY_CLOSERS);
      if (cps[i] === '#') i = skipComponent(cps, i, FRAGMENT_CLOSERS);

      const restLen = i - (prefixStart + prefixCpLen);
      // Length of the matched span in the *input*, measured in
      // codepoints from the start of the link (after any scheme
      // offset) to wherever we stopped.
      const matchLength = (i - postStart) - schemeOffset;
      if (this.maxLength != null && matchLength > this.maxLength) continue;

      const start = postStart + schemeOffset;
      const tail = cpSlice(cps, prefixStart + prefixCpLen, prefixStart + prefixCpLen + restLen);
      result.push({
        url: `${proto}${hn}${tail}`,
        indices: [start, start + matchLength],
      });
    }
    return result;
  }

  extractUrls(text) {
    return this.extractUrlsWithIndices(text).map((r) => r.url);
  }

  // Returns every email address found in `text` as a list of objects:
  //
  //   { email: String, url: String, indices: [start, end] }
  //
  // `email` is the bare address ("info@example.com"); `url` is the same
  // thing as a mailto: URL, so the result drops straight into anything
  // that already renders a `url` entity. Both carry the IDN-decoded
  // domain. `indices` are codepoint offsets, `end` exclusive, and
  // absorb a leading "mailto:" if the input had one (UTS #58 §5.2).
  //
  // A plain address overlaps the bare domain after the '@' that
  // extractUrlsWithIndices would find; see extractEntitiesWithIndices
  // in index.js for the merge that resolves this.
  extractEmailAddressesWithIndices(text) {
    const cps = toCodepoints(text);
    const result = [];
    for (let at = 0; at < cps.length; at++) {
      if (cps[at] !== '@') continue;

      // Walk left over the run of local-part characters. We stop one past
      // the RFC 5321 limit and bail: a run longer than that means this isn't
      // an address, not that its last 64 characters are one. Scanning
      // (rather than slicing the whole prefix and matching anchored) is what
      // keeps '@'-dense input from going O(n²).
      let localStart = at;
      while (localStart > 0 &&
             LP_CHAR.test(cps[localStart - 1]) &&
             at - localStart < MAX_LOCALPART_CP + 1) {
        localStart--;
      }
      const localLen = at - localStart;
      if (localLen === 0 || localLen > MAX_LOCALPART_CP) continue;
      const local = cpSlice(cps, localStart, at);
      if (local.startsWith('.') || local.endsWith('.') || local.includes('..')) {
        continue;
      }

      const afterStr = cpSlice(cps, at + 1,
        Math.min(cps.length, at + 1 + MAX_HOST_SCAN_CP));
      const pm = PREFIX_RE.exec(afterStr);
      if (!pm) continue;
      const prefixCpLen = toCodepoints(pm[0]).length;
      if (prefixCpLen >= 254) continue;

      const hostRaw = pm[0].replace(/。/g, '.');
      const hn = idnToUnicode(hostRaw);
      if (!this.isPlausibleHost(hn)) continue;

      const endPos = at + 1 + prefixCpLen;
      // UTS #58 §5.2 step 6: absorb a leading "mailto:" into the span.
      if (localStart >= 7 &&
          cpSlice(cps, localStart - 7, localStart).toLowerCase() === 'mailto:') {
        localStart -= 7;
      }
      if (this.maxLength != null && (endPos - localStart) > this.maxLength) {
        continue;
      }
      result.push({
        email: `${local}@${hn}`,
        url: `mailto:${local}@${hn}`,
        indices: [localStart, endPos],
      });
    }
    return result;
  }

  extractEmailAddresses(text) {
    return this.extractEmailAddressesWithIndices(text).map((r) => r.email);
  }

  // Sorts `entities` by start offset and drops any whose [start, end)
  // overlaps the survivor before it. The earlier-starting entity wins;
  // length plays no part, so a long candidate is dropped if it begins
  // inside a shorter earlier one. Ties on start are broken by input
  // order. Doesn't mutate `entities`.
  removeOverlappingEntities(entities) {
    const sorted = [...entities].sort((a, b) => a.indices[0] - b.indices[0]);
    const out = [];
    let prev = null;
    for (const e of sorted) {
      if (prev && prev.indices[1] > e.indices[0]) continue;
      out.push(e);
      prev = e;
    }
    return out;
  }
}
