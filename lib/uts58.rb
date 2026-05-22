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
# extractors before resolving overlap yourself).
#
#   Uts58.extract_urls("see example.com here")
#   # => ["https://example.com"]
#
#   Uts58.extract_urls_with_indices("see example.com here")
#   # => [{ url: "https://example.com", indices: [4, 15] }]
module Uts58
  VERSION = "0.1.1"

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

    private

    def extractor
      @extractor ||= Extractor.new
    end
  end
end

require_relative "uts58/extractor"
