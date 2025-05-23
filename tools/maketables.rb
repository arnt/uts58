#!/bin/ruby
require "byebug"

print "    OPENERS = {\n"
File.readlines("/tmp/link-paired-opener", chomp: true).each do |line|
  if m = /^([0-9A-F]*);\s*([0-9A-F]*)\s*(#.*)/.match(line) then
    print "      0x#{m.match(1)} => 0x#{m.match(2)}, #{m.match(3)}\n"
  end
end
print "    }.freeze\n"

data = []
File.readlines("/tmp/link-termination", chomp: true).each do |line|
  m = /^([0-9A-F]*)(\.\.([0-9A-F]*))?;\s*(\S+)\s+(\#.*)/.match(line)
  if m then
    cp1 = m.match(1).to_i(16)
    if m.match(2).nil? then
      data[cp1] = { state: m.match(4), comment: m.match(5) }
    else
      cp2 = m.match(3).to_i(16)
      (cp1..cp2).each do |cp|
        data[cp] = { state: m.match(4), comment: m.match(5) }
      end
    end
  end
end

# I think Psion managed to squeeze a data structure like this one into
# 35k ROM; this one looks very redundant. Maybe move all the really
# long repetitions into a separate table indexed by cp/1024 and check
# that first?
print "    LINK_TERMINATION = {\n"
comment = nil
data.each.with_index do |v, i|
  if v.nil?
    comment = nil
  else
    print "      0x#{i.to_s(16)} => :#{v[:state].downcase},"
    c = v[:comment]
    if c != comment then
      comment = c
      print " ", comment
    end
    print "\n"
  end
end
print "    }.freeze\n"
