# uts58

This repo contains two implementations of
[UTS58](https://www.unicode.org/reports/tr58/),
the Unicode spec for finding links in running text. Given a chunk of text,
they return the URLs and email addresses in it along with their character
offsets.

CI for [the Ruby code](https://github.com/arnt/uts58/tree/main/ruby): [![CI](https://github.com/arnt/uts58/actions/workflows/ruby.yml/badge.svg)](https://github.com/arnt/uts58/actions/workflows/ruby.yml)
and for [the Javascript code](https://github.com/arnt/uts58/tree/main/javascript): [![CI](https://github.com/arnt/uts58/actions/workflows/javascript.yml/badge.svg)](https://github.com/arnt/uts58/actions/workflows/javascript.yml)

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
