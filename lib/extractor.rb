# encoding: utf-8
require 'simpleidn'
require 'public_suffix'
require 'constants'

module Uts58
  class Extractor
    # The This documentation and the API is nearly identical to
    # Twitter::TwitterText::Extractor::extract_urls_with_indices, so
    # that Mastodon can use it

    # Extracts all URLs in the <tt>text</tt> along with the indices for
    # where the entity ocurred If the <tt>text</tt> is <tt>nil</tt> or
    # contains no entity an empty array will be returned.
    #
    # options is an array that may contain :extract_url_without_protocol.

    PATH_CLOSERS = [35, 47, 63]
    QUERY_CLOSERS = [35] # how about &?
    FRAGMENT_CLOSERS = []

    def extract_urls_with_indices(text, options = {})
      result = []
      text.to_enum(:scan,/(?<![-\p{Alnum}\p{M}.])(?=\p{Alnum}[-\p{L}\p{N}\p{M}\u00DF\u03C2\u06FD\u06FE\u0F0B\u3007]*[\.:。])/).map{Regexp.last_match}.each do |match|
        # get rid of a leading protocol.
        s = match.post_match
        if /^(https?:\/\/)/i.match(s)
          proto = Regexp.last_match(1)
          s = s.sub( /^https?:\/\//i, "" )
        else
          proto = "https://"
        end
        # look for the prefix that might be a hostname or an IDN.
        # this is a somewhat sloppy match, with a few false positives.
        prefix = /^([-\p{L}\p{N}\p{M}\u00DF\u03C2\u06FD\u06FE\u0F0B\u3007]+[\.。]){1,4}[-\p{L}\p{N}\p{M}]+(?![-\p{L}\p{N}\p{M}])/.match(s)
        if prefix && prefix.match(0).length < 254 then
          hn = SimpleIDN.to_unicode(prefix.match(0).gsub(/。/, "."))
          begin
            about = PublicSuffix.parse(hn,
                                       ignore_private: true,
                                       default_rule: nil)
            if about && about.tld != "invalid" then
              # at this point, we do have enough to mark something,
              # the question is how much. there may be a trailing
              # port, then a path, then a query, finally a fragment.
              rest = prefix.post_match
              # port
              port = /^:\d+/.match(rest)
              rest = port.post_match if port
              # path
              rest = skip_component(rest, PATH_CLOSERS) while rest[0] == "/"
              # query
              rest = skip_component(rest, QUERY_CLOSERS) if rest[0] == '?'
              rest = skip_component(rest, FRAGMENT_CLOSERS) if rest[0] == "#"
              rest_length = prefix.post_match.length - rest.length
              match_length = match.post_match.length - rest.length
              result << {
                url: "#{proto}#{hn}#{prefix.post_match[...rest_length]}",
                indices: [match.begin(0), match.begin(0) + match_length]
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

    private

    def fix_url(text)
      text
    end

    def followed_by_hard(codepoints, i)
      j = i;
      while(j < codepoints.length &&
            Constants::TERMINATION.include?(codepoints[j]) &&
            Constants::TERMINATION[codepoints[j]] == :soft)
        j = j + 1
      end
      j >= codepoints.length ||
        (Constants::TERMINATION.include?(codepoints[j]) &&
         Constants::TERMINATION[codepoints[j]] == :hard)
    end

    def skip_component(string, extra_closers)
      openers = []
      codepoints = string.codepoints
      codepoints.each.with_index do |cp, i|
        if i == 0
          # it's the lead-in character
        elsif extra_closers.include? cp
          return string[i..]
        elsif Constants::TERMINATION.include?(cp)
          case Constants::TERMINATION[cp]
          when :hard
            return string[i..]
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
          end
        else
          # it's a letter or something like that
        end
      end
    end
  end
end
