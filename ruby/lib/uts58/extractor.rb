# frozen_string_literal: true
require 'simpleidn'
require 'public_suffix'
require_relative 'constants'

module Uts58
  # Finds links in arbitrary text per UTS58. The public API mirrors
  # Twitter::TwitterText::Extractor closely enough that twitter-text
  # consumers (notably Mastodon) can easily swap one for the other.
  #
  # Instances carry only optional configuration (see #max_length=); if
  # you don't need to set anything, the module-level shortcuts
  # are simpler.
  #
  # Note that this may often find overlapping link candiates,
  # e.g. "contact example@example.com for details" may find a mailto
  # link and also a link to +https://example.com+. You'll almost
  # certainly want to #remove_overlapping_entities after extracting
  # the kinds of entities you want and merging the lists.
  #
  # (Bluesky handles vs. web sites are another example of common
  # overlap, Fediverse vs. email a third, Tibetan domains
  # vs. themselves a less common fourth, the list goes on.)
  class Extractor
    PATH_CLOSERS = [35, 47, 63]
    QUERY_CLOSERS = [35]
    FRAGMENT_CLOSERS = []
    QUERY_SEPARATORS = [0x3d, 0x26]           # = and & begin a new query part
    DIRECTIVE_SEPARATORS = [0x2c, 0x3d, 0x26] # , = and & within a :~: directive

    # Maximum allowed length of the matched text, in input codepoints.
    # Matches whose input span exceeds this are dropped from the result
    # of #extract_urls_with_indices and the other extraction methods.
    #
    # "Matched text" means the substring that came out of +text+ — for
    # example 11 for <tt>"example.com"</tt>. The returned +:url+ can
    # be both longer and shorter, most commonly when a missing scheme
    # is filled in ( +"https://example.com"+ is 19 codepoints). The
    # limit is measured against the input, not against the returned
    # URL.
    #
    # Default is +nil+, meaning no limit.
    attr_accessor :max_length

    def initialize
      @max_length = nil
    end

    # Returns every URL found in +text+ as a list of hashes:
    #
    #   { url: String, indices: [start, end] }
    #
    # +url+ is the cleaned-up form: any A-labels in the hostname are
    # decoded to U-labels, and the scheme is filled in as +https://+
    # if the input had none. +indices+ are codepoint offsets into
    # +text+, with +end+ exclusive, so <tt>text[start...end]</tt>
    # gives the substring that matched.
    #
    # Note that the start and end may not match the length of url. One
    # very common example is input that like "foo example.com bar",
    # where the URL will be https://example.com, including "https://".
    #
    # Returns an empty array if +text+ contains no links. +options+ is
    # accepted for twitter-text compatibility and currently ignored.
    def extract_urls_with_indices(text, options = {})
      result = []
      # The '@' in the negative lookbehind is non-obvious part: UTS58
      # has no userinfo, so a host that immediately follows an '@'
      # cannot be a link to https://. An email address (or a
      # bluesky/mastodon one) is possible. The rest of the set just
      # keeps a trigger from firing inside a word or path.
      text.to_enum(:scan,/(?<![-\p{Alnum}\p{M}.\/@])(?=\p{Alnum}[-\p{L}\p{N}\p{M}\u00DF\u03C2\u06FD\u06FE\u0F0B\u3007]*[\.:。])/).map{Regexp.last_match}.each do |match|
        # get rid of a leading protocol. We also tolerate letter/mark/number
        # characters between the trigger and the scheme, so that input
        # like "テストhttp://example.com" attaches the scheme correctly:
        # the trigger fires at offset 0 (the start of "テスト") because
        # nothing precedes it, and the actual link begins three
        # codepoints later.
        s = match.post_match
        scheme_match = /^([\p{Han}\p{Hiragana}\p{Katakana}\p{Hangul}\p{Thai}\p{Lao}\p{Khmer}\p{Myanmar}]*?)(https?:\/\/)/i.match(s)
        if scheme_match
          scheme_offset = scheme_match[1].length
          proto = scheme_match[2]
          s = scheme_match.post_match
        else
          scheme_offset = 0
          proto = "https://"
        end
        # look for the prefix that might be a hostname or an IDN.
        # this is a somewhat sloppy match, with a few false positives.
        prefix = /^([-\p{L}\p{N}\p{M}\u00DF\u03C2\u06FD\u06FE\u0F0B\u3007]+[\.。]){1,4}[-\p{L}\p{N}\p{M}]+(?![-\p{L}\p{N}\p{M}])/.match(s)
        if prefix && prefix[0].length < 254
          host_raw = prefix.match(0).gsub(/。/, ".")
          next unless valid_labels?(host_raw)
          hn = SimpleIDN.to_unicode(host_raw)
          begin
            about = PublicSuffix.parse(hn,
                                       ignore_private: true,
                                       default_rule: nil)
            if about && about.tld != "invalid" then
              # at this point, we do have enough to mark something,
              # the question is how much. there may be a trailing
              # port, then a path, then a query, finally a fragment.
              rest = prefix.post_match
              # "example.com." keeps its trailing dot only when a path, query,
              # or fragment follows; at the end of a sentence it's prose (UTS58).
              if rest[0] == "." && ["/", "?", "#"].include?(rest[1])
                rest = rest[1..]
              end
              # a port number must be 1..65535
              port = /^:(\d+)/.match(rest)
              if port
                n = port[1].to_i
                next if n < 1 || n > 65535
                rest = port.post_match
              end
              # path
              rest = skip_component(rest, PATH_CLOSERS) while rest[0] == "/"
              # query
              rest = skip_component(rest, QUERY_CLOSERS, QUERY_SEPARATORS) if rest[0] == '?'
              rest = skip_component(rest, FRAGMENT_CLOSERS, [], DIRECTIVE_SEPARATORS) if rest[0] == "#"
              rest_length = prefix.post_match.length - rest.length
              match_length = match.post_match.length - rest.length - scheme_offset
              next if @max_length && match_length > @max_length
              start = match.begin(0) + scheme_offset
              result << {
                url: "#{proto}#{hn}#{prefix.post_match[...rest_length]}",
                indices: [start, start + match_length]
              }
            end
          rescue PublicSuffix::DomainInvalid
            # evidently we're not looking at the start of a link
          rescue PublicSuffix::DomainNotAllowed
            # ditto
          end
        end
      end
      # ah! the good feeling of going home after a hard day's work
      result
    end

    # Returns just the URLs found in +text+, as an array of strings,
    # in the order they occur. Use #extract_urls_with_indices instead
    # if you also need the offsets, e.g. for adding HTML markup or for
    # pairing the found links with the form used in the text.
    #
    # For text such as "a example.com b", this returns ["https://example.com"].
    def extract_urls(text, options = {})
      extract_urls_with_indices(text, options).map { |r| r[:url] }
    end

    # Returns every email address found in +text+ as a list of hashes:
    #
    #   { email: String, url: String, indices: [start, end] }
    #
    # +email+ is the bare address ( <tt>"info@example.com"</tt> ); +url+ is
    # the same thing as a +mailto:+ URL ( <tt>"mailto:info@example.com"</tt> ), so
    # that the result drops straight into anything that already knows how
    # to render a <tt>:url</tt> entity. Both carry the IDN-decoded domain
    # (A-labels become U-labels, as in #extract_urls_with_indices).
    # +indices+ are codepoint offsets, +end+ exclusive; they cover a
    # leading +mailto:+ in the input if there was one, per UTS58 5.2.
    #
    # #extract_urls_with_indices does not match a host that immediately
    # follows an <tt>@</tt> — UTS58 has no userinfo, so "info@example.com"
    # never yields a bare +example.com+ link. To get such an address as plain
    # text rather than a +mailto:+ link, extract both kinds, merge with
    # #remove_overlapping_entities, then drop the survivors that have an
    # +:email+ key; that leaves the span unlinked.
    #
    # Returns an empty array if +text+ contains no addresses. +options+ is
    # accepted for twitter-text compatibility and currently ignored.
    def extract_email_addresses_with_indices(text, options = {})
      result = []
      text.to_enum(:scan, /@/).map{Regexp.last_match}.each do |match|
        at_pos = match.begin(0)
        pre = text[0...at_pos]
        lp_match = /[\p{XID_Continue}.!#$%&'*+\-\/=?^_`{|}~]+\z/.match(pre)
        next unless lp_match
        local = lp_match[0]
        next if local.start_with?('.') || local.end_with?('.') || local.include?('..')
        s = match.post_match
        prefix = /^([-\p{L}\p{N}\p{M}ßς۽۾་〇]+[\.。]){1,4}[-\p{L}\p{N}\p{M}]+(?![-\p{L}\p{N}\p{M}])/.match(s)
        next unless prefix && prefix[0].length < 254
        host_raw = prefix.match(0).gsub(/。/, ".")
        next unless valid_labels?(host_raw)
        hn = SimpleIDN.to_unicode(host_raw)
        begin
          about = PublicSuffix.parse(hn, ignore_private: true, default_rule: nil)
          next unless about && about.tld != "invalid"
        rescue PublicSuffix::DomainInvalid, PublicSuffix::DomainNotAllowed
          next
        end
        local_start = at_pos - local.length
        end_pos = at_pos + 1 + prefix[0].length
        # UTS58 5.2 step 6: absorb a leading "mailto:" into the span.
        if local_start >= 7 && text[(local_start - 7)...local_start].downcase == "mailto:"
          local_start -= 7
        end
        next if @max_length && (end_pos - local_start) > @max_length
        result << {
          email: "#{local}@#{hn}",
          url: "mailto:#{local}@#{hn}",
          indices: [local_start, end_pos]
        }
      end
      result
    end

    def extract_email_addresses(text, options = {})
      extract_email_addresses_with_indices(text, options).map { |r| r[:email] }
    end

    # Given a list of entities (hashes with an +:indices+ key of the
    # shape <tt>[start, end]</tt>, as produced by
    # #extract_urls_with_indices) drops every entity that overlaps an
    # earlier one and returns the survivors.
    #
    # Useful when merging the output of several extractors (URLs,
    # mentions, hashtags, …), or when #extract_urls_with_indices itself
    # finds several partly overlapping candidate URLs and you want only
    # the longest. The algorithm prefers entries that start earlier;
    # ties are broken by input order.
    #
    # The input array is not modified.
    def remove_overlapping_entities(entities)
      sorted = entities.sort_by { |e| e[:indices].first }
      prev = nil
      sorted.reject do |e|
        if prev && prev[:indices].last > e[:indices].first
          true
        else
          prev = e
          false
        end
      end
    end

    private

    # A label may not start or end with a hyphen (the LDH rule), so a host
    # like -foo.example-.com is not a link at all. The prefix regex already
    # rejects empty labels; xn-- A-labels pass, since they neither start nor
    # end with '-'.
    def valid_labels?(host)
      host.split(".").none? { |label| label.start_with?("-") || label.end_with?("-") }
    end

    # UTS58 Link_Term for a code point: :include, :soft, :open, :close, or nil
    # for Hard — the @missing default for anything not in Constants::LINK_TERM.
    # Binary search over the sorted ranges.
    def link_term(cp)
      ranges = Constants::LINK_TERM
      lo = 0
      hi = ranges.length - 1
      while lo <= hi
        mid = (lo + hi) / 2
        start, finish, value = ranges[mid]
        if cp < start
          hi = mid - 1
        elsif cp > finish
          lo = mid + 1
        else
          return value
        end
      end
      nil
    end

    def followed_by_hard(codepoints, i)
      j = i
      j += 1 while j < codepoints.length && link_term(codepoints[j]) == :soft
      j >= codepoints.length || link_term(codepoints[j]).nil?
    end

    def skip_component(string, extra_closers, separators = [], directive_separators = nil)
      openers = []
      seps = separators
      codepoints = string.codepoints
      i = 0
      while i < codepoints.length
        cp = codepoints[i]
        if i == 0
          # it's the lead-in character
        elsif extra_closers.include? cp
          return string[i..]
        elsif directive_separators && cp == 0x3a && codepoints[i + 1] == 0x7e && codepoints[i + 2] == 0x3a
          # ":~:" begins a fragment text directive; its own separators take
          # over and bracket pairing restarts (the directive is a fresh part).
          openers = []
          seps = directive_separators
          i += 2
        elsif seps.include?(cp)
          # A separator ends one part of the component. UTS58 pairs brackets
          # per part, so the stack restarts here, but the link continues.
          openers = []
        else
          case link_term(cp)
          when :include
            # part of the link; keep scanning
          when :soft
            return string[i..] if followed_by_hard(codepoints, i)
          when :close
            if Constants::OPENERS[cp] == openers.last
              openers.pop
            else
              return string[i..]
            end
          when :open
            openers << cp
          else # nil => Hard, the UTS58 default: the link ends here
            return string[i..]
          end
        end
        i += 1
      end
      # Input ran out before any terminator did: the whole component
      # belongs to the URL, so there is nothing left over.
      ""
    end
  end
end
