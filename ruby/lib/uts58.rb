# frozen_string_literal: true

# Ruby implementation of {UTS #58}[https://www.unicode.org/reports/tr58/],
# the Unicode spec for finding links in running text.
#
# The two entry points below are module-level shortcuts around a single
# memoised Uts58::Extractor instance. They also strip partly
# overlapping links — if the extractor finds two candidates that share
# any characters in the input, the wrappers keep the earlier one and
# drop the rest. Use Uts58::Extractor directly if you want the
# raw, possibly-overlapping list (e.g. to merge with hashtag/mention
# extractors before resolving overlap).
#
#   Uts58.extract_urls("see example.com here")
#   # => ["https://example.com"]
#
#   Uts58.extract_urls_with_indices("see example.com here")
#   # => [{ url: "https://example.com", indices: [4, 15] }]
module Uts58
  VERSION = "0.2.1"

  class << self
    # Like Uts58::Extractor#extract_urls_with_indices, but with
    # overlapping results merged via
    # Uts58::Extractor#remove_overlapping_entities.
    def extract_urls_with_indices(text, options = {})
      extractor.remove_overlapping_entities(
        extractor.extract_urls_with_indices(text, options)
      )
    end

    # Like Uts58::Extractor#extract_urls, but with the URLs of
    # overlapping results merged.
    def extract_urls(text, options = {})
      extract_urls_with_indices(text, options).map { |r| r[:url] }
    end

    # Like Uts58::Extractor#extract_email_addresses_with_indices, but
    # with overlapping results merged.
    def extract_email_addresses_with_indices(text, options = {})
      extractor.remove_overlapping_entities(
        extractor.extract_email_addresses_with_indices(text, options)
      )
    end

    # Like Uts58::Extractor#extract_email_addresses, but with
    # overlapping results merged.
    def extract_email_addresses(text, options = {})
      extract_email_addresses_with_indices(text, options).map { |r| r[:email] }
    end

    # Both the URLs and email addresses in +text+, as one list of
    # mixed-shape hashes — <tt>{ url:, indices: }</tt> for links and
    # <tt>{ email:, indices: }</tt> for addresses — sorted by start
    # offset with overlaps removed. The name and mixed-shape return
    # follow Twitter::TwitterText::Extractor#extract_entities_with_indices.
    #
    # Overlap is the point of going through here rather than calling the
    # two extractors yourself: "contact info@grå.org today" yields both
    # an email and the bare domain grå.org, and only one of those should
    # survive. The earlier-starting candidate (the email) wins.
    def extract_entities_with_indices(text, options = {})
      extractor.remove_overlapping_entities(
        extractor.extract_urls_with_indices(text, options) +
        extractor.extract_email_addresses_with_indices(text, options)
      )
    end

    # Like ::extract_entities_with_indices, but flattened to the bare
    # URL strings, in the order they occur. Email addresses appear in
    # their +mailto:+ form, e.g. "contact info@example.com or look at
    # example.com" returns [<tt>"mailto:info@example.com"</tt>,
    # <tt>"https://example.com"</tt>].
    def extract_entities(text, options = {})
      extract_entities_with_indices(text, options).map { |e| e[:url] }
    end

    private

    def extractor
      @extractor ||= Extractor.new
    end
  end
end

require_relative "uts58/extractor"
