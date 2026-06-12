# uts58

A Ruby implementation of [UTS #58](https://www.unicode.org/reports/tr58/),
the Unicode spec for finding links in running text. Given a chunk of text,
it returns the URLs and email addresses in it along with their character
offsets.

Both halves of UTS #58 are covered: **web links** and **email addresses**.
The two are detected independently and can be combined.

Tested extensively on relevant OSes: [![CI](https://github.com/arnt/uts58/actions/workflows/ruby.yml/badge.svg)](https://github.com/arnt/uts58/actions/workflows/ruby.yml)

## Install

```ruby
gem "uts58"
```

## Usage

```ruby
require "uts58"

Uts58.extract_urls_with_indices("see https://example.com/ for details")
# => [{ url: "https://example.com/", indices: [4, 24] }]

Uts58.extract_urls("see https://example.com/ for details")
# => ["https://example.com/"]
```

The API mirrors `Twitter::TwitterText::Extractor#extract_urls_with_indices`
closely; it was written to provide what Mastodon uses. The two module-level
methods above also strip partly overlapping matches; you can use
`Uts58::Extractor` directly if you'd rather merge with other extractors
(mentions, hashtags, …) and resolve overlap across all of them yourself.

Input without a scheme is recognised, and `https://` is prepended in the
returned `:url`:

```ruby
Uts58.extract_urls_with_indices("blogspot.com is still a thing")
# => [{ url: "https://blogspot.com", indices: [0, 12] }]
```

IDNs are decoded to use UTF8 in the output, for better readability:

```ruby
Uts58.extract_urls("xn-----ctdbabcfhu9c2b9l1acccr4c.xn--mgbah1a3hjkrd").first
# => "https://تجربة-القبول-الشامل.موريتانيا"
```

(Admittedly that output isn't very readable if you can't read Arabic.
But the input wasn't readable to anyone, no matter what languages they
can read.)

Trailing punctuation, balanced brackets, ports, paths, queries and fragments
are handled per the spec.

## Email addresses

Email detection mirrors the URL methods. Each result carries the address
twice — as a bare `:email` and as a `mailto:` `:url` — so it drops straight
into anything that already renders a `:url` entity:

```ruby
Uts58.extract_email_addresses_with_indices("write to info@grå.org today")
# => [{ email: "info@grå.org",
#       url: "mailto:info@grå.org",
#       indices: [9, 21] }]

Uts58.extract_email_addresses("write to info@grå.org today")
# => ["info@grå.org"]
```

UTS #58 allows Unicode local-parts, so `阿Q@例子.中国` and `उदाहरण@उदाहरण.भारत`
are recognised; the domain is IDN-decoded just like a URL host. A leading
`mailto:` in the input is folded into the matched span.

## Combined extraction

`extract_entities_with_indices` runs both detectors, sorts by offset, and
strips overlaps — mirroring `Twitter::TwitterText::Extractor#extract_entities_with_indices`.
The result is a mixed list of `:url` and email (`:email` + `:url`) hashes:

```ruby
Uts58.extract_entities_with_indices("mail arnt@grå.org or see blogspot.com")
# => [{ email: "arnt@grå.org", url: "mailto:arnt@grå.org", indices: [5, 17] },
#     { url: "https://blogspot.com", indices: [25, 37] }]

Uts58.extract_entities("mail arnt@grå.org or see blogspot.com")
# => ["mailto:arnt@grå.org", "https://blogspot.com"]
```

### Not wanting `mailto:` links

`info@example.com` overlaps the bare domain `example.com` that the URL scan
finds after the `@`. If you'd rather not turn addresses into `mailto:` links,
you have two options, with different results for `contact info@example.com for pricing`:

1. **Extract both, then drop emails.** Take `extract_entities_with_indices`
   (already overlap-stripped) and reject the hashes that have an `:email`
   key. The address wins the overlap, so dropping it leaves that span
   *unlinked* — `info@example.com` stays plain text. Choose this if an
   address shouldn't silently become a website link.
2. **Extract only URLs.** Call `extract_urls_with_indices` and skip email
   detection entirely. The URL scan finds domain after the `@`, so the
   same input links to `https://example.com`. Choose this if you'd
   rather fall back to the domain.

## What's not here

- **Link validation.** Recognised URLs are not fetched, normalised beyond
  IDN decoding, or their hostnames checked in the DNS. If you need this,
  send me mail.

## Roadmap

My immediate need is UTS58 conformant link detection suitable for
public web pages. If you need something more, I rather think that an
item can be added to this roadmap, so long as the description in the
rdoc remains short and simple. Send mail to arnt@gulbrandsen.priv.no.

## License

BSD-2-Clause. See `LICENSE`.

FWIW, I wrote this as part of my work at ICANN and will maintain it as
part of the same work. (I resolve problems relating to Unicode in
domains, email addresses and similar, so more people, more
communities, can use the internet in the way they prefer.)
