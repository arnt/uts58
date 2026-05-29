# encoding: utf-8
# frozen_string_literal: true
require 'bundler/setup'
require 'uts58'

RSpec.describe "Extraction" do
  before(:all) do
    @extractor = Uts58::Extractor.new
  end
  def extract_urls(text)
    @extractor.extract_urls_with_indices(text)
  end

  it "does not accept an invalid domain" do
    expect(extract_urls("a test.x b").count).to eq(0)
    # hm... PublicSuffix accepts .invalid as a valid TLD.
    expect(extract_urls("a test.invalid b").count).to eq(0)
  end

  it "accepts blogspot.com as a domain" do
    expect(extract_urls("a blogspot.com b").count).to eq(1)
  end

  it "does not regard .com has a domain" do
    expect(extract_urls("a com b").count).to eq(0)
  end

  it "handles ports sensibly" do
    x = extract_urls("a example.com:443 b");
    expect(x.count).to eq(1)
    expect(x.first[:indices]).to eq([2, 17])
  end

  it "includes a path" do
    x = extract_urls("a example.com/123 b");
    expect(x.count).to eq(1)
    expect(x.first[:indices]).to eq([2, 17])
  end

  it "includes a query" do
    x = extract_urls("a example.com?123 b");
    expect(x.count).to eq(1)
    expect(x.first[:indices]).to eq([2, 17])
  end

  it "includes a fragment" do
    x = extract_urls("a example.com#123 b");
    expect(x.count).to eq(1)
    expect(x.first[:indices]).to eq([2, 17])
  end

  it "includes a giant long thing" do
    x = extract_urls("a example.com/123?123#123 b");
    expect(x.count).to eq(1)
    expect(x.first[:indices]).to eq([2, 25])
  end

  it "finishes before trailing parens" do
    x = extract_urls("a (example.com/123?123#123) b");
    expect(x.first[:indices]).to eq([3, 26])
    x = extract_urls("a (example.com/123?123#(123)) b")
    expect(x.first[:indices]).to eq([3,28])
  end

  it "is clever about full stops" do
    x = extract_urls("a example.com/123.html b");
    expect(x.first[:indices]).to eq([2, 22])
    x = extract_urls("a example.com/123. HTML is great");
    expect(x.first[:indices]).to eq([2,17])
    x = extract_urls("a example.com/123... HTML is so great");
    expect(x.first[:indices]).to eq([2,17])
    x = extract_urls("a example.com/123.");
    expect(x.first[:indices]).to eq([2,17])
  end

  it "decodes a-labels in the resulting URL" do
    x = extract_urls("xn-----ctdbabcfhu9c2b9l1acccr4c.xn--mgbah1a3hjkrd")
    expect(x.count).to eq(1)
    expect(x.first[:url]).to eq("https://تجربة-القبول-الشامل.موريتانيا")
  end

  uasg004domains = [
    #, 1, ASCII.ASCII, new-long, Long ASCII
    "universal-acceptance-test.international",
    #, 2, ASCII.ASCII, new-short, Short ASCII
    "universal-acceptance-test.icu",
    #, 3, IDN.IDN, RTL, Arabic
    "تجربة-القبول-الشامل.موريتانيا",
    #, 4, IDN.IDN, , Armenian
    "համընդհանուր-ընկալում-թեստ.հայ",
    #, 5, IDN.IDN, , Bengali Bangla
    "সর্বজনীন-স্বীকৃতির-পরীক্ষা.ভারত",
    #, 6, IDN.IDN, , Cyrillic
    "универсальное-принятие-тест.москва",
    #, 7, IDN.IDN, , Devanagari
    "सार्वभौमिक-स्वीकृति-परीक्षण.संगठन",
    #, 8, IDN.IDN, , Georgian
    "უნივერსალური-თავსობადობის-ტესტი.გე",
    #, 9, IDN.IDN, , Greek
    "καθολική-αποδοχή-δοκιμή.ευ",
    #, 10, IDN.IDN, , Gujarati
    "સાર્વત્રિક-સ્વીકૃતિ-પરીક્ષણ.ભારત",
    #, 11, IDN.IDN, , Gurmukhi
    "ਸਰਵਵਿਆਪਕ-ਪ੍ਰਵਾਨਗੀ-ਪਰਖ.ਭਾਰਤ",
    #, 12, IDN.IDN, , Hangul
    "다국어도메인이용환경테스트.한국",
    #, 13, IDN.IDN, RTL, Hebrew
    "מבחן-קבלה-אוניברסלי.קום",
    #, 14, IDN.IDN, , Hiragana
    "どこでもつかえる.みんな",
    #, 15, IDN.IDN, , Kannada
    "ಸಾರ್ವತ್ರಿಕ-ಸ್ವೀಕಾರಾರ್ಹತೆ-ಪರೀಕ್ಷೆ.ಭಾರತ",
    #, 16, IDN.IDN, , Katakana
    "ユニバーサルアクセプタンス.クラウド",
    #, 17, IDN.IDN, , Lao
    "ສາກົນ-ການຍອມຮັບ-ທົດລອງ.ລາວ",
    #, 19, IDN.IDN, , Malayalam
    "സാർവത്രിക-സ്വീകാര്യതാ-പരിശോധന.ഭാരതം",
    #, 20, IDN.IDN, , Oriya
    "ଯୁନିଭରସାଲ-ଏକସେପ୍ଟନ୍ସ-ଟେଷ୍ଟ.ଭାରତ",
    #, 21, IDN.IDN, , Sinhala
    "විශ්ව-සම්මුති-පිරික්සුම.ලංකා",
    #, 22, IDN.IDN, , Tamil
    "பொது-ஏற்பு-சோதனை.சிங்கப்பூர்",
    #, 23, IDN.IDN, , Telugu
    "యూనివర్సల్-ఆమోదం-పరీక్ష.భారత్",
    #, 24, IDN.IDN, , Thai
    "ยูเอทดสอบ.ไทย",
    #, 25, IDN.IDN, , Simplified Chinese
    "普遍适用测试.我爱你",
    #, 26, IDN.IDN, , Traditional Chinese
    "普遍適用測試.台灣",
    #, 27, IDN.ASCII, , Ethiopic
    "ሁለንአቀፍ-ተቀባይነት-ሙከራ.com",
    #, 28, IDN.ASCII, , Khmer
    "ការសាកល្បងទទួលយកជាអន្តរជាតិ.com",
    #, 29, IDN.ASCII, , Myanmar
    "အလုံးစုံလက်ခံမှုစမ်းသပ်ချက်.com",
    #, 30, IDN.ASCII, RTL, Thaana
    "ދުނިޔެ-ގަބޫލުކުރާ-ޓެސްޓު.com",
    #, 63, ASCII.IDN, RTL, Hebrew
    "universal-acceptance-test.קום",
    #, 64, IDN.ASCII, , Latin
    "épreuve-acceptation-universelle.org",
  ]
  uasg004domains.each do |url|
    it "can pick UASG004 test domain #{url} out of text" do
      more = "Lorem ipsum #{url} dolor sit amet"
      x = extract_urls(more)
      expect(x.count).to eq(1)
      expect(x.first[:url]).to eq("https://#{url}")
    end
  end

  it "can pick UASG004 test ཡོངས་ཁྱབ་ངོས་ལེན་བརྟག་དཔྱད.com out of text" do
    x = extract_urls("Lorem ipsum ཡོངས་ཁྱབ་ངོས་ལེན་བརྟག་དཔྱད.com dolor sit amet")
    expect(x.map{|y| y[:url]}).to include("https://ཡོངས་ཁྱབ་ངོས་ལེན་བརྟག་དཔྱད.com")
  end

  uasg004misc = [
    #, 18, IDN.IDN, , Latin
    "Universales-Akzeptanz-Test.vermögensberatung",
    #, 65, IDN.ASCII, not in NFC normalization form, Latin
    "épreuve-acceptation-universelle.org",
    #, 66, IDN.IDN, Ideographic Full Stop, Simplified Chinese
    "普遍适用测试。我爱你",
    #, 67, IDN.IDN, RTL; A-label.U-label, Arabic
    # "موريتانيا.xn-----ctdbabcfhu9c2b9l1acccr4c", TLD not delegated as of 2025
    #, 68, IDN.IDN, RTL; U-label.A-label, Arabic
    "تجربة-القبول-الشامل.xn--mgbah1a3hjkrd",
    #, 69, IDN.IDN, RTL; A-label.A-label, Arabic
    "xn-----ctdbabcfhu9c2b9l1acccr4c.xn--mgbah1a3hjkrd",
    #, 70, ASCII.ASCII/Unicode, , Simplified Chinese
    "universal-acceptance-test.icu/测试",
    #, 71, IDN.IDN/Unicode, , Simplified Chinese
    "普遍适用测试.我爱你/测试",
    #, 72, IDN.IDN/Unicode, RTL, Arabic
    "تجربة-القبول-الشامل.موريتانيا/تجربة"
  ]
  uasg004misc.each do |url|
    it "can pick UASG004 test #{url} out of text" do
      more = "Lorem ipsum #{url} dolor sit amet"
      x = extract_urls(more)
      expect(x.count).to eq(1)
    end
  end

  # 31 is special; extract_urls will pick several partly overlapping
  # substrings. Selecting the longest is a separate task
  it "can pick UASG004 test ཡོངས་ཁྱབ་ངོས་ལེན་བརྟག་དཔྱད.com out of text" do
    x = extract_urls("Lorem ipsum ཡོངས་ཁྱབ་ངོས་ལེན་བརྟག་དཔྱད.com dolor sit amet")
    expect(x.map{|y| y[:url]}).to include("https://ཡོངས་ཁྱབ་ངོས་ལེན་བརྟག་དཔྱད.com")
  end

  # what a joy that UTS58 doesn't consider email addresses; that way
  # this code doesn't need to include test UASG004 test case number
  # 69, and I don't need to look at that abomination.

  urls = [ "example.com" ]
  urls.each do |url|
    it "can pick a plain domain" do
      more = "Lorem ipsum #{url} dolor sit amet"
      expect(extract_urls(more).count).to eq(1)
    end
  end

  # based on a comment in twitter-text
  it "can pick Wikipedia articles from text" do
    expect(extract_urls("blah en.wikipedia.org/wiki/The_Lovemakers_(film) blah").count).to eq(1)
  end

  # based on a test in php-autolink
  it "can pick Wikipedia articles from text" do
    expect(extract_urls("blah example.com/?foo[1]=a&amp;foo[2]=b blah").first[:url]).to eq("https://example.com/?foo[1]=a&amp;foo[2]=b")
  end

  # based on a comment in twitter-text
  [
    "comoyo.com/play/S(123)",
    "example.com/knutsen_ludvigsen/ver(k)ste(d)/brilleslange.mp3",
    "example.com/Bob_Marley/Rastaman_Vibration/11_Jah_Live_(originally_issued_as_Island_Single_(WIP_6265))_(bonus_track)"
  ].each do |url|
    it "can handle complicated song player URLs" do
      more = "Lorem ipsum #{url} dolor sit amet"
      expect(extract_urls(more).first[:url]).to eq("https://#{url}")
    end
  end

  # based on tests in rails-autolink
  [ "business.timesonline.co.uk/article/0,,9065-2473189,00.html",
    "www.mail-archive.com/ruby-talk@ruby-lang.org/",
    "tools.ietf.org/html/rfc3986",
    "www.amazon.com/Testing-Equal-Sign-In-Path/ref=pd_bbs_sr_1?ie=UTF8&s=books&qid=1198861734&sr=8-1",
    "www.google.com/doku.php?id=gps:resource:scs:start",
    "maps.google.co.uk/maps?f=q&q=the+london+eye&ie=UTF8&ll=51.503373,-0.11939&spn=0.007052,0.012767&z=16&iwloc=A",
    "www.rubyonrails.com/foo.cgi?trailing_hyphen=value-",
    "www.rubyonrails.com/foo.cgi?trailing_forward_slash=value/"
  ].each do |url|
    [ url, "https://#{url}" ].each do |u|
      it "can pick #{u} from text" do
        expect(extract_urls("blah #{u} blah").first[:url]).to eq("https://#{url}")
      end
    end
  end

  # rails-autolink contains a timeout test... let's try harder!
  it "should not be led astray by a LONG link" do
    expect(extract_urls("blah #{"example."*100000}com blah").count).to eq(0)
  end

  # The following block of tests is ported from the Java reference
  # implementation in ICU (com.ibm.icu.text.LinkDetector).

  it "handles empty input" do
    expect(extract_urls("").count).to eq(0)
  end

  it "finds two non-overlapping URLs in one string" do
    x = extract_urls("a blogspot.com b example.com c")
    expect(x.count).to eq(2)
    expect(x.map { |r| r[:url] }).to eq(["https://blogspot.com", "https://example.com"])
  end

  it "does not detect a second link inside an embedded URL" do
    url = "https://archive.org/20260225/https://example.com/example"
    x = extract_urls("foo #{url} bar")
    expect(x.count).to eq(1)
    expect(x.first[:url]).to eq(url)
  end

  # UTS58 only recognises http and https. ftp:, ssh:, sftp:, ldap:
  # etc. must not produce a result for the embedded hostname.
  ["ftp://ftp.archaic.example.com",
   "ssh://server.example.com",
   "sftp://files.example.com",
   "ldap://directory.example.com"].each do |u|
    it "does not linkify the host inside an unsupported scheme: #{u}" do
      expect(extract_urls("foo #{u} bar").count).to eq(0)
    end
  end

  it "preserves http:// when the input has it" do
    x = extract_urls("foo http://example.com bar")
    expect(x.count).to eq(1)
    expect(x.first[:url]).to eq("http://example.com")
  end

  it "rejects port 0" do
    expect(extract_urls("a example.com:0 b").count).to eq(0)
  end

  it "rejects ports above 65535" do
    expect(extract_urls("a example.com:100000 b").count).to eq(0)
  end

  it "accepts low and mid-range ports" do
    expect(extract_urls("a example.com:1 b").count).to eq(1)
    expect(extract_urls("a example.com:1000 b").count).to eq(1)
    expect(extract_urls("a example.com:65535 b").count).to eq(1)
  end

  it "terminates at a surplus closing bracket with no opener on the stack" do
    x = extract_urls("a example.com/foo) b")
    expect(x.count).to eq(1)
    expect(x.first[:url]).to eq("https://example.com/foo")
  end

  it "terminates at a mismatched closing bracket" do
    x = extract_urls("a example.com/foo(bar] b")
    expect(x.count).to eq(1)
    expect(x.first[:url]).to eq("https://example.com/foo(bar")
  end

  it "finds an http:// link directly preceded by non-Latin letters" do
    x = extract_urls("テストhttp://example.com/日本語")
    expect(x.count).to eq(1)
    expect(x.first[:url]).to eq("http://example.com/日本語")
    expect(x.first[:indices]).to eq([3, 25])
  end

  it "keeps the path when the input ends with one" do
    x = extract_urls("Visit https://example.com/example")
    expect(x.count).to eq(1)
    expect(x.first[:url]).to eq("https://example.com/example")
  end

  it "treats surrounding square brackets as terminators" do
    x = extract_urls("a [example.com/path] b")
    expect(x.count).to eq(1)
    expect(x.first[:url]).to eq("https://example.com/path")
  end

  describe "Extractor#extract_urls" do
    it "returns only the URL strings" do
      expect(@extractor.extract_urls("a blogspot.com b example.com c"))
        .to eq(["https://blogspot.com", "https://example.com"])
    end
  end

  describe "Extractor#max_length" do
    it "defaults to nil so nothing is filtered out" do
      e = Uts58::Extractor.new
      expect(e.max_length).to be_nil
      expect(e.extract_urls("foo example.com bar").count).to eq(1)
    end

    it "drops matches whose input span exceeds the limit" do
      e = Uts58::Extractor.new
      e.max_length = 10  # "example.com" is 11 codepoints, so over the limit
      expect(e.extract_urls("foo example.com bar")).to eq([])
    end

    it "keeps matches whose input span equals the limit" do
      e = Uts58::Extractor.new
      e.max_length = "example.com".length
      expect(e.extract_urls("foo example.com bar")).to eq(["https://example.com"])
    end

    # The limit is measured against the matched substring of the
    # input, not against the returned URL (which is often longer
    # because the scheme is filled in).
    it "measures the input span, not the returned URL" do
      e = Uts58::Extractor.new
      e.max_length = 11  # length of "example.com"; URL is "https://example.com" (19)
      expect(e.extract_urls("foo example.com bar")).to eq(["https://example.com"])
    end

    it "still drops a scheme-bearing match whose input span exceeds the limit" do
      e = Uts58::Extractor.new
      # "https://example.com" is 19 input codepoints; URL is also 19.
      e.max_length = 15
      expect(e.extract_urls("foo https://example.com bar")).to eq([])
    end

    it "filters per-match, keeping shorter ones in a mixed input" do
      e = Uts58::Extractor.new
      e.max_length = 12  # keeps "blogspot.com" (12), drops "universal-acceptance-test.icu" (29)
      x = e.extract_urls("see blogspot.com and universal-acceptance-test.icu please")
      expect(x).to eq(["https://blogspot.com"])
    end
  end

  describe "Extractor#remove_overlapping_entities" do
    it "drops later entries that start inside an earlier entry's span" do
      entities = [
        { url: "a", indices: [0, 10] },
        { url: "b", indices: [5, 15] },  # overlaps a
        { url: "c", indices: [10, 20] }, # touches a but doesn't overlap
        { url: "d", indices: [12, 18] }, # overlaps c
      ]
      expect(@extractor.remove_overlapping_entities(entities).map { |e| e[:url] })
        .to eq(["a", "c"])
    end

    it "is a no-op on an empty or already-disjoint list" do
      expect(@extractor.remove_overlapping_entities([])).to eq([])
      disjoint = [{ url: "a", indices: [0, 5] }, { url: "b", indices: [10, 15] }]
      expect(@extractor.remove_overlapping_entities(disjoint)).to eq(disjoint)
    end
  end

  describe "Extractor#extract_email_addresses_with_indices" do
    def extract_emails(text)
      @extractor.extract_email_addresses_with_indices(text)
    end

    # Table 5-1 from UTS #58: positive cases.
    it "extracts a plain ASCII address" do
      x = extract_emails("Contact abcd@example.com")
      expect(x.count).to eq(1)
      expect(x.first[:email]).to eq("abcd@example.com")
      expect(x.first[:url]).to eq("mailto:abcd@example.com")
      expect(x.first[:indices]).to eq([8, 24])
    end

    it "includes a medial dot in the local-part" do
      x = extract_emails("Contact x.abcd@example.com")
      expect(x.count).to eq(1)
      expect(x.first[:email]).to eq("x.abcd@example.com")
    end

    it "accepts a non-ASCII local-part" do
      x = extract_emails("Contact አርበርቶ.አርበርቶ@example.com")
      expect(x.count).to eq(1)
      expect(x.first[:email]).to eq("አርበርቶ.አርበርቶ@example.com")
    end

    it "accepts the Greek example from UTS #58 §5.1" do
      x = extract_emails("write to σωκράτης@example.com")
      expect(x.count).to eq(1)
      expect(x.first[:email]).to eq("σωκράτης@example.com")
    end

    it "handles a mix of ASCII/non-ASCII combinations" do
      [
        "grå@grå.org",
        "info@grå.org",
        "arnt@grå.org",
        "阿Q@例子.中国",
        "例子@例子.中国",
        "उदाहरण@उदाहरण.भारत",
        "gøril@example.com",
      ].each do |addr|
        x = extract_emails("hi #{addr} there")
        expect(x.count).to eq(1), "expected to extract #{addr}"
        expect(x.first[:email]).to eq(addr)
      end
    end

    # Table 5-1 from UTS #58: negative cases.
    it "rejects an address with no valid domain" do
      expect(extract_emails("Contact x@example.😎").count).to eq(0)
    end

    it "rejects an address with no local-part" do
      expect(extract_emails("Contact @example.com").count).to eq(0)
    end

    it "rejects a local-part that ends with a dot" do
      expect(extract_emails("Contact john.@example.com").count).to eq(0)
    end

    it "rejects a local-part with consecutive dots" do
      expect(extract_emails("Contact john..doe@example.com").count).to eq(0)
    end

    it "rejects a local-part that starts with a dot" do
      expect(extract_emails("Contact .john.doe@example.com").count).to eq(0)
    end

    # UTS #58 §5.2 step 6: mailto: is absorbed into the matched span.
    it "absorbs a leading mailto: into the span" do
      x = extract_emails("see mailto:abcd@example.com please")
      expect(x.count).to eq(1)
      expect(x.first[:email]).to eq("abcd@example.com")
      expect(x.first[:url]).to eq("mailto:abcd@example.com")
      expect(x.first[:indices]).to eq([4, 27])
    end

    it "absorbs a mailto: only at a clean boundary" do
      # "foomailto:" should not be absorbed; the local-part scan still
      # picks up the longest valid prefix, but the mailto: prefix logic
      # only fires when "mailto:" is literally at offset start-7.
      x = extract_emails("foomailto:abcd@example.com")
      expect(x.count).to eq(1)
      # local-part is the maximal trailing run of Link_Email chars,
      # which includes "foomailto" minus the colon, i.e. "abcd".
      expect(x.first[:email]).to eq("abcd@example.com")
    end

    it "decodes A-labels in the domain" do
      x = extract_emails("write to arnt@xn-----ctdbabcfhu9c2b9l1acccr4c.xn--mgbah1a3hjkrd")
      expect(x.count).to eq(1)
      expect(x.first[:email]).to eq("arnt@تجربة-القبول-الشامل.موريتانيا")
    end

    it "finds two addresses in one text" do
      x = extract_emails("from arnt@grå.org to gøril@example.com today")
      expect(x.map { |r| r[:email] }).to eq(["arnt@grå.org", "gøril@example.com"])
    end

    it "rejects a bare @ with no local-part or domain" do
      expect(extract_emails("a @ b").count).to eq(0)
    end

    it "respects max_length" do
      e = Uts58::Extractor.new
      e.max_length = 10
      expect(e.extract_email_addresses("see abcd@example.com")).to eq([])
      e.max_length = "abcd@example.com".length
      expect(e.extract_email_addresses("see abcd@example.com"))
        .to eq(["abcd@example.com"])
    end
  end

  describe "module-level email wrappers" do
    it "exposes Uts58.extract_email_addresses_with_indices" do
      expect(Uts58.extract_email_addresses_with_indices("write arnt@grå.org now").first[:email])
        .to eq("arnt@grå.org")
    end

    it "exposes Uts58.extract_email_addresses" do
      expect(Uts58.extract_email_addresses("write arnt@grå.org now"))
        .to eq(["arnt@grå.org"])
    end
  end

  describe "module-level combined entity wrappers" do
    it "returns both urls and emails as mixed-shape hashes" do
      x = Uts58.extract_entities_with_indices("mail arnt@grå.org or see blogspot.com")
      expect(x.count).to eq(2)
      expect(x[0][:email]).to eq("arnt@grå.org")
      expect(x[0][:url]).to eq("mailto:arnt@grå.org")
      expect(x[1][:url]).to eq("https://blogspot.com")
    end

    it "keeps the email and drops the bare domain when they overlap" do
      # "info@grå.org" is an address; "grå.org" inside it is also a bare
      # domain. The earlier-starting email wins.
      x = Uts58.extract_entities_with_indices("contact info@grå.org today")
      expect(x.count).to eq(1)
      expect(x.first[:email]).to eq("info@grå.org")
    end

    it "sorts entities by start offset" do
      x = Uts58.extract_entities_with_indices("see blogspot.com then mail gøril@example.com")
      expect(x.map { |e| e[:url] })
        .to eq(["https://blogspot.com", "mailto:gøril@example.com"])
    end

    it "flattens to mailto/https url strings via extract_entities" do
      expect(Uts58.extract_entities("mail arnt@grå.org or see blogspot.com"))
        .to eq(["mailto:arnt@grå.org", "https://blogspot.com"])
    end

    it "returns an empty list for text with neither" do
      expect(Uts58.extract_entities_with_indices("nothing to see here")).to eq([])
      expect(Uts58.extract_entities("nothing to see here")).to eq([])
    end
  end

  describe "module-level wrappers" do
    it "exposes Uts58.extract_urls_with_indices" do
      expect(Uts58.extract_urls_with_indices("see example.com here").first[:url])
        .to eq("https://example.com")
    end

    it "exposes Uts58.extract_urls" do
      expect(Uts58.extract_urls("see example.com here"))
        .to eq(["https://example.com"])
    end

    # The Tibetan tseg (U+0F0B) acts as a label separator inside the
    # domain, so the raw extractor finds the full domain plus several
    # shorter suffixes. The wrapper should keep only the longest one.
    it "strips overlapping candidates and keeps the longest match" do
      tibetan = "ཡོངས་ཁྱབ་ངོས་ལེན་བརྟག་དཔྱད.com"
      text = "Lorem ipsum #{tibetan} dolor sit amet"
      raw = Uts58::Extractor.new.extract_urls_with_indices(text)
      expect(raw.count).to be > 1

      wrapped = Uts58.extract_urls_with_indices(text)
      expect(wrapped.count).to eq(1)
      expect(wrapped.first[:url]).to eq("https://#{tibetan}")
    end
  end
end
