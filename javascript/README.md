# uts58

A JavaScript implementation of [UTS58](https://www.unicode.org/reports/tr58/),
the Unicode spec for finding links in running text. Given a chunk of text, it
returns the URLs in it along with their codepoint offsets. This is a port of
the [Ruby `uts58` gem](https://github.com/arnt/uts58); the test suite is the
same, with very minor differences.

Tested extensively on relevant OSes: [![CI](https://github.com/arnt/uts58/actions/workflows/javascript.yml/badge.svg)](https://github.com/arnt/uts58/actions/workflows/javascript.yml)

## Install

```sh
npm install uts58
```

ESM-only; Node 18+ (uses Unicode property escapes and lookbehinds).

## Usage

```js
import { extractUrls, extractUrlsWithIndices } from 'uts58';

extractUrlsWithIndices('see https://example.com/ for details');
// => [{ url: 'https://example.com/', indices: [4, 24] }]

extractUrls('see https://example.com/ for details');
// => ['https://example.com/']
```

The API mirrors `twitter-text`'s `Extractor#extractUrlsWithIndices` closely;
it was written to provide what Mastodon-style consumers need. The two
top-level functions above also strip partly overlapping matches via
`Extractor#removeOverlappingEntities`: candidates are sorted by start
offset and anything that begins inside an earlier survivor's span is
dropped. Length doesn't enter into it — the earlier-starting candidate
wins even if a later one is longer. Import `Extractor` directly if you'd
rather merge with other extractors (mentions, hashtags, …) and resolve
overlap across all of them yourself.

Unlike `twitter-text`, the functions take no options object. What counts as
a link is fixed by [UTS58](https://www.unicode.org/reports/tr58/); there is
no `extractUrlsWithoutProtocol`-style switch, because the spec already says
how scheme-less input is handled (see below).

Input without a scheme is recognised, and `https://` is prepended in the
returned `url`:

```js
extractUrlsWithIndices('blogspot.com is still a thing');
// => [{ url: 'https://blogspot.com', indices: [0, 12] }]
```

IDNs are decoded to use UTF-8 in the output, for better readability:

```js
extractUrls('xn-----ctdbabcfhu9c2b9l1acccr4c.xn--mgbah1a3hjkrd')[0];
// => 'https://تجربة-القبول-الشامل.موريتانيا'
```

(Admittedly that output isn't very readable if you can't read Arabic. But
the input wasn't readable to anyone, no matter what languages they can read.)

Trailing punctuation, balanced brackets, ports, paths, queries and
fragments are handled per the spec. Indices in the output are
codepoint offsets, not UTF-16 code unit offsets. `text.slice(start,
end)` won't give back the matched substring if the text contains
characters outside the BMP. Convert the codepoint indices using
`Array.from(text)` if you need to slice. `example.com/🐪/#camel` is a
good test case: the emoji is a single codepoint but two UTF-16 code
units, so every offset after it shifts by one.

## Email addresses

```js
import {
  extractEmailAddresses,
  extractEmailAddressesWithIndices,
  extractEntities,
  extractEntitiesWithIndices,
} from 'uts58';

extractEmailAddressesWithIndices('contact info@grå.org today');
// => [{ email: 'info@grå.org', url: 'mailto:info@grå.org', indices: [8, 20] }]

extractEmailAddresses('contact info@grå.org today');
// => ['info@grå.org']
```

Each result carries both the bare `email` and a `mailto:` `url`, so it
drops straight into anything that already renders a `url` entity. The
domain is IDN-decoded the same way as in `extractUrls`, and a leading
`mailto:` in the input is absorbed into `indices` per UTS58 §5.2.

A plain address overlaps the bare domain that `extractUrls` would find
after the `@`. `extractEntitiesWithIndices` runs both extractors,
sorts by start offset, and removes overlaps — the earlier-starting
email wins over the domain inside it:

```js
extractEntities('mail arnt@grå.org or see blogspot.com');
// => ['mailto:arnt@grå.org', 'https://blogspot.com']
```

## Choosing the public-suffix check

To decide whether `something.example` is a plausible link, the extractor
checks the host against a public-suffix table. Which table is a bundle-time
choice — pick the entry point that fits, and your bundler ships only that
table:

| import | table | gzipped |
| --- | --- | --- |
| `uts58` (default) | Public Suffix List, ICANN section | ~5 KB |
| `uts58/iana` | IANA root-zone TLDs | ~5 KB |
| `uts58/core` | none — you supply the check | 0 KB |

All three expose the same API. The two tables are about the same size and
agree on nearly every host — the difference is how strict the check is for
the handful of TLDs that only register at the second level. `uts58/iana`
asks only "is the rightmost label a real TLD": enough to tell `blogspot.jp`
from `blogspot.exe` and to reject typos like `example.cmo`, but it treats a
bare `foo.za` as plausible. The default `uts58` carries the PSL, which knows
South Africa registers under `co.za` / `org.za` and so rejects a bare
`foo.za`. If that distinction doesn't matter to you, the tables are
interchangeable.

Neither reproduces the PSL's wildcard/exception rules: the question here is
"could this be a link", not "where is the exact registrable boundary", so a
flat membership test is all it does. The PSL table is folded accordingly —
`!` exceptions dropped, `*.foo` collapsed to `foo`, and any suffix made
redundant by a shorter one removed (with `no` present, `møre-og-romsdal.no`
is dropped). That folding is what keeps it down to ~5 KB.

`uts58/core` bundles no table at all. Bring your own check — over a suffix
set, or wrapping a library you already depend on:

```js
import { Extractor } from 'uts58/core';
import { parse } from 'tldts';

const ex = new Extractor({
  isPlausibleHost: (host) => {
    const p = parse(host);
    return !!p.domain && p.isIcann && p.publicSuffix !== 'invalid';
  },
});
ex.extractUrls('see example.com here');
```

That route is also how you get exact PSL semantics back, at the cost of a
dependency you choose rather than one this package forces on you. (`uts58`
itself depends only on `punycode`.)

## Suggested test cases and notable behaviour

A few sharp edges worth covering in your own tests if you're swapping
`twitter-text` out, or just using this from scratch.

**The `href` and the visible text are not the same string.** For
`see example.com here`, `indices` covers the 11 codepoints of
`example.com`, but `url` is the 19-codepoint `https://example.com`.
Use `url` for the `href` attribute, slice the original text by
`indices` for the visible content. A test that compares
`text.slice(start, end) === url` will fail on every scheme-less input,
and on every IDN where A-labels got decoded.

**Indices are codepoints.** `text.slice(start, end)` works only as long
as the text stays inside the BMP. `https://example.com/🐪/#camel` is
the test case I'd recommend for anyone wrapping matches in `<a>`: the
camel is one codepoint but two UTF-16 units, so the end index is
exactly one short of what `String.prototype.slice` expects. Pay
particular attention to where the link ends — off-by-one here will
chop the last character of the fragment or include the first
character of whatever follows. Convert via `Array.from(text).slice(…)`
or precompute UTF-16 offsets if you'd rather slice once.

**No options object.** There is no `extractUrlsWithoutProtocol: false`
switch. If you want only scheme-bearing URLs, filter on the matched
substring (not on `url`, which always carries `https://`):

```js
const cps = Array.from(text);
extractUrlsWithIndices(text)
  .filter((r) => /^https?:\/\//i.test(cps.slice(...r.indices).join('')));
```

**No `autoLink`.** This package extracts; it doesn't render. There's
no equivalent of `twitter-text`'s `autoLink`, `autoLinkUrlsCustom`,
`htmlEscape`, etc. — building HTML is the caller's job, which keeps
escaping decisions where they belong.

**No mentions, hashtags, cashtags, replies.** UTS58 doesn't define
them, so this package doesn't either. If you need them, run
`twitter-text` (or another extractor) for those alongside this one and
merge with `Extractor#removeOverlappingEntities`.

**Overlap resolution is start-wins, not longest-wins.** Worth a test
when you merge entities from multiple extractors.  `ask
alice@example.com/02074960909 for details` shows why. The raw
extractors find both email `alice@example.com` at `[4, 21]` and url
`https://example.com/02074960909` at `[10, 33]`. Start-wins keeps
`alice@example.com`, which is what a reader would call right.
Longest-wins would keep the longer `https://example.com/02074960909`.

**`maxLength` measures the matched input span.** Not the returned URL.
A 12-codepoint cap keeps `blogspot.com` (12) and drops
`https://example.com` (19 input codepoints), even though the input
span and `url` happen to be identical there. The asymmetry shows up
the other way for `example.com` (11 input cp, 19 in `url`) — the cap
of 12 keeps it.

**`mailto:` is absorbed into `indices`.** Per UTS58 §5.2, the input
`mailto:abcd@example.com` returns an entity whose span covers the
whole 23-codepoint run, not just the address. The `email` field still
holds the bare address. If your link-rendering code assumes the span
starts at the local-part, mailto inputs will surprise it.

## What's not here

- **Link validation.** Recognised URLs are not fetched, normalised
  beyond IDN decoding, or their hostnames checked in the DNS. There is
  no attempt at checking for possible attacks (`Мышκин.рф` and
  `Мышкин.рф` are both detected, note the Greek kappa in the middle of
  the prince's name).

## Regenerating the generated tables

`src/constants.js` is generated from the Ruby reference's `constants.rb`
(which is in turn generated from the UTS58 data files). To refresh:

```sh
npm run maketables -- /path/to/uts58/lib/uts58/constants.rb
```

`src/tlds-iana.js` and `src/suffixes-psl.js` are the public-suffix tables.
With no arguments they're fetched from their canonical sources
([IANA](https://data.iana.org/TLD/tlds-alpha-by-domain.txt),
[PSL](https://publicsuffix.org/list/public_suffix_list.dat)); pass local
paths to regenerate offline:

```sh
npm run maketlds
npm run maketlds -- /path/to/tlds-alpha-by-domain.txt /path/to/public_suffix_list.dat
```

## License

BSD-2-Clause. See `LICENSE`.

FWIW, I wrote this as part of my work at ICANN and will maintain it as
part of the same work. (I resolve problems relating to Unicode in
domains, email addresses and similar, so more people, more
communities, can use the internet in the way they prefer.)
