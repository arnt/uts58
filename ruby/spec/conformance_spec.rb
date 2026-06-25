# encoding: utf-8
# frozen_string_literal: true
require 'bundler/setup'
require 'set'
require 'uts58'

# The official UTS58 conformance suite, LinkDetectionTest.txt. Each non-comment
# line carries zero or more links wrapped in ⸠…⸡; we strip the markers,
# re-detect, re-wrap, and require the result to match the line.
#
# The lines we don't pass are in LinkDetectionKnownFailures.txt, which are
# failures according to the conformance test, not according to the text.
RSpec.describe "LinkDetectionTest.txt conformance" do
  OPEN = "⸠"
  CLOSE = "⸡"
  DATA_DIR = File.expand_path("../..", __dir__)

  def self.read_cases(name)
    File.read(File.join(DATA_DIR, name)).split("\n")
        .reject { |line| line.empty? || line.start_with?("#") }
  end

  before(:all) { @extractor = Uts58::Extractor.new }

  # Detect links in +input+ and wrap each in the markers, working in codepoints
  # so astral characters don't shift the offsets.
  def detect_and_mark(input)
    entities = @extractor.extract_urls_with_indices(input) +
               @extractor.extract_email_addresses_with_indices(input)
    entities = @extractor.remove_overlapping_entities(entities)
                         .sort_by { |e| e[:indices][0] }
    cps = input.chars
    out = +""
    cursor = 0
    entities.each do |e|
      start, finish = e[:indices]
      out << cps[cursor...start].join << OPEN << cps[start...finish].join << CLOSE
      cursor = finish
    end
    out << cps[cursor..].join
  end

  cases = read_cases("LinkDetectionTest.txt")
  known = read_cases("LinkDetectionKnownFailures.txt").to_set

  it "matches every line not listed as a known failure" do
    regressed = []
    cases.each do |expected|
      input = expected.delete(OPEN).delete(CLOSE)
      got = detect_and_mark(input)
      next if got == expected || known.include?(input)
      regressed << "  in : #{input}\n  exp: #{expected}\n  got: #{got}"
    end
    expect(regressed).to be_empty,
      "newly failing conformance lines:\n#{regressed.join("\n")}"
  end

  it "lists no line that already passes" do
    fixed = cases.filter_map do |expected|
      input = expected.delete(OPEN).delete(CLOSE)
      input if known.include?(input) && detect_and_mark(input) == expected
    end
    expect(fixed).to be_empty,
      "these now pass — delete them from LinkDetectionKnownFailures.txt:\n  #{fixed.join("\n  ")}"
  end
end
