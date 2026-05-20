# uts58

A Ruby implementation of [UTS #58](https://www.unicode.org/reports/tr58/),
the Unicode spec for finding links in running text. Given a chunk of text,
it returns the URLs in it along with their character offsets.

This covers the **web link** half of UTS #58 only. Email address recognition
is not implemented here since at the moment it's unclear whether that's
desirable on generally visible web pages.

Tested extensively on relevant OSes: [![CI](https://github.com/arnt/uts58/actions/workflows/ci.yml/badge.svg)](https://github.com/arnt/uts58/actions/workflows/ci.yml)

## Install

```ruby
gem "uts58"
```

## Usage

```ruby
require "uts58"

extractor = Uts58::Extractor.new
extractor.extract_urls_with_indices("see https://example.com/ for details")
# => [{ url: "https://example.com/", indices: [4, 24] }]
```

The API mirrors `Twitter::TwitterText::Extractor#extract_urls_with_indices`
closely; it was written to provide what Mastodon uses.

Input without a scheme is recognised, and `https://` is prepended in the
returned `:url`:

```ruby
extractor.extract_urls_with_indices("blogspot.com is still a thing")
# => [{ url: "https://blogspot.com", indices: [0, 12] }]
```

IDNs are decoded to use UTF8 in the output, for better readability:

```ruby
extractor.extract_urls_with_indices("xn-----ctdbabcfhu9c2b9l1acccr4c.xn--mgbah1a3hjkrd").first[:url]
# => "https://تجربة-القبول-الشامل.موريتانيا"
```

(Admittedly that output isn't very readable if you can't read Arabic.
But the input wasn't readable to anyone, no matter what languages they
can read.)

Trailing punctuation, balanced brackets, ports, paths, queries and fragments
are handled per the spec.

## What's not here

- **Email addresses.** UTS #58 covers them; this gem doesn't. If you
  need that, send me mail and explain what you need.
- **Link validation.** Recognised URLs are not fetched, normalised beyond
  IDN decoding, or their hostnames checked in the DNS.

## License

BSD-2-Clause. See `LICENSE`.
