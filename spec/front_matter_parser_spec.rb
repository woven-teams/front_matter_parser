require 'spec_helper'

describe FrontMatterParser do
  let(:sample_fm) { {'title' => 'hello'} }

  it 'has a version number' do
    expect(FrontMatterParser::VERSION).to_not be_nil
  end

  describe "#parse" do
    context "when the string has both front matter and content" do
      let(:parsed) { FrontMatterParser.parse(string) }

      it "parses the front matter as a hash" do
        expect(parsed.front_matter).to eq(sample_fm)
      end

      it "parses the content as a string" do
        expect(parsed.content).to eq("Content")
      end
    end

    context "when the string only has front matter" do
      let(:parsed) { FrontMatterParser.parse(string_no_content) }

      it "parses the front matter as a hash" do
        expect(parsed.front_matter).to eq(sample_fm)
      end

      it "parses the content as an empty string" do
        expect(parsed.content).to eq('')
      end
    end

    context "when an empty front matter is supplied" do
      let(:parsed) { FrontMatterParser.parse(string_no_front_matter) }

      it "parses the front matter as an empty hash" do
        expect(parsed.front_matter).to eq({})
      end

      it "parses the content as the whole string" do
        expect(parsed.content).to eq("Content")
      end
    end

    context "when an empty string is supplied" do
      let(:parsed) { FrontMatterParser.parse('') }

      it "parses the front matter as an empty hash" do
        expect(parsed.front_matter).to eq({})
      end

      it  "parses the content as an empty string" do
        expect(parsed.content).to eq('')
      end
    end

    context "when :comment option is given" do
      it "takes it as the single line comment mark for the front matter" do
        parsed = FrontMatterParser.parse(string_comment('#'), comment: '#')
        expect(parsed.front_matter).to eq(sample_fm)
      end

      context "when :start_comment is given" do
        it "raises an ArgumentError" do
          expect { FrontMatterParser.parse(string_comment('#'), comment: '#', start_comment: '/')}.to raise_error ArgumentError
        end
      end
    end

    context "when :start_comment option is given" do
      context "when :end_comment option is not given" do
        it "takes :start_comment as the mark for a multiline comment closed by indentation for the front matter" do
          parsed = FrontMatterParser.parse(string_start_comment('/'), start_comment: '/')
          expect(parsed.front_matter).to eq(sample_fm)
        end
      end

      context "when :end_comment option is provided" do
        it "takes :start_comment and :end_comment as the multiline comment mark delimiters for the front matter" do
          parsed = FrontMatterParser.parse(string_start_end_comment('<!--', '-->'), start_comment: '<!--', end_coment: '-->')
          expect(parsed.front_matter).to eq(sample_fm)
        end
      end
    end

    context "when :end_comment option is given but :start_comment is not" do
      it "raises an ArgumentError" do
        expect {FrontMatterParser.parse(string_start_end_comment, end_comment: '-->')}.to raise_error(ArgumentError)
      end
    end

    context "when :syntax is given" do
      {
        slim: [:slim, nil, '/', nil],
        'coffee script' => [:coffee, '#', nil, nil],
        html: [:html, nil, '<!--', '-->'],
        haml: [:haml, nil, '-#', nil],
        liquid: [:liquid, nil, '<% comment %>', '<% endcomment %>'],
        sass: [:sass, '//', nil, nil],
        scss: [:scss, '//', nil, nil],
        md: [:md, nil, nil, nil],
      }.each_pair do |syntax, prop|
        it "can detect a #{syntax} syntax" do
          parsed = FrontMatterParser.parse(File.read(File.expand_path("../fixtures/example.#{prop[0]}", __FILE__)), syntax: prop[0])
          expect(parsed.front_matter).to eq(sample_fm)
        end
      end
    end
  end

  describe "#parse_file" do
    context "when autodetect is true" do
      {
        slim: ['slim', nil, '/', nil],
        coffee: ['coffee', '#', nil, nil],
        html: ['html', nil, '<!--', '-->'],
        haml: ['haml', nil, '-#', nil],
        liquid: ['liquid', nil, '<% comment %>', '<% endcomment %>'],
        sass: ['sass', '//', nil, nil],
        scss: ['scss', '//', nil, nil],
        md: ['md', nil, nil, nil],
      }.each_pair do |format, prop|
        it "can detect a #{format} file" do
          expect(FrontMatterParser).to receive(:parse).with(File.read(File.expand_path("../fixtures/example.#{prop[0]}", __FILE__)), comment: prop[1], start_comment: prop[2], end_comment: prop[3])
          FrontMatterParser.parse_file(File.expand_path("../fixtures/example.#{prop[0]}", __FILE__), autodetct: true)
        end
      end

      context "when the file extension is unknown" do
        it "raises a RuntimeError" do
          expect {FrontMatterParser.parse_file(File.expand_path('../fixtures/example.foo', __FILE__), autodetect: true)}.to raise_error(RuntimeError)
        end
      end
    end

    context "when autodetect is false" do
      it "calls #parse with the content of the file and given comment delimiters" do
        expect(FrontMatterParser).to receive(:parse).with(File.read(File.expand_path('../fixtures/example.md', __FILE__)), comment: nil, start_comment: nil, end_comment: nil)
        FrontMatterParser.parse_file(File.expand_path('../fixtures/example.md', __FILE__), autodetect: false)
      end
    end
  end
end

describe "the front matter" do
  let(:sample_fm) { {'title' => 'hello'} }

  it "can be indented" do
    string = %Q(
  ---
  title: hello
  ---
Content)
    expect(FrontMatterParser.parse(string).front_matter).to eq(sample_fm)
  end

  it "can have each line commented" do
    string = %Q(
#---
#title: hello
#---
Content)
    expect(FrontMatterParser.parse(string, comment: '#').front_matter).to eq(sample_fm)
  end

  it "can be indented after the comment delimiter" do
    string = %Q(
#  ---
#  title: hello
#  ---
Content)
    expect(FrontMatterParser.parse(string, comment: '#').front_matter).to eq(sample_fm)
  end

  it "can be between a multiline comment" do
    string = %Q(
<!--
---
title: hello
---
-->
Content)
    expect(FrontMatterParser.parse(string, start_comment: '<!--', end_comment: '-->').front_matter).to eq(sample_fm)
  end

  it "can have the multiline comment delimiters indented" do
    string = %Q(
    <!--
    ---
    title: hello
    ---
    -->
Content)
    expect(FrontMatterParser.parse(string, start_comment: '<!--', end_comment: '-->').front_matter).to eq(sample_fm)
  end

  it "can have empty lines between the multiline comment delimiters and the front matter" do
    string = %Q(
<!--

---
title: hello
---

-->
Content)
    expect(FrontMatterParser.parse(string, start_comment: '<!--', end_comment: '-->').front_matter).to eq(sample_fm)
  end

  it "can have multiline comment delimited by indentation" do
    string = %Q(
  /
    ---
    title: hello
    ---
  Content)
    expect(FrontMatterParser.parse(string, start_comment: '/').front_matter).to eq(sample_fm)
  end
end

def string
"---
title: hello
---
Content"
end

def string_no_front_matter
"Content"
end

def string_no_content
"---
title: hello
---
"
end

def string_comment(comment)
"#{comment} ---
#{comment} title: hello
#{comment} ---
Content"
end

def string_start_comment(start_comment)
"#{start_comment}
  ---
  title: hello
  ---
Content"
end

def string_start_end_comment(start_comment, end_comment)
"#{start_comment}
---
title: hello
---
#{end_comment}
Content"
end
