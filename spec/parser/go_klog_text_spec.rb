require_relative '../spec_helper'
require_relative '../../lib/parser/go_klog_text'

RSpec.describe LogsParser::Parser::GoKlogText do
  describe '#parse' do
    subject { described_class.new }

    specify 'standard metadata' do
      raw = 'E0123 12:34:56.789       42 pkg/main4ever.go:123] "oh no"'
      err, result = subject.parse(raw)
      expect(err).to be_nil
      expect(result).to have_attributes(
        level: LogsParser::StructuredMessage::LEVEL_ERROR,
        time: '12:34:56.789',
        raw: raw,
        properties: {
          'code' => '0123',
          'source_file' => 'pkg/main4ever.go',
          'source_line' => 123,
        },
      )
    end

    specify 'invalid metadata' do
      err, result = subject.parse('E0123 12:34:56.789       42 pkg/main4ever.go:123')
      expect(err).to be_nil
      expect(result).to be_nil
    end

    specify 'log levels' do
      err, result = subject.parse('E0123 12:34:56.789       42 pkg/main4ever.go:123] "oh no"')
      expect(err).to be_nil
      expect(result.level).to eq(LogsParser::StructuredMessage::LEVEL_ERROR)

      err, result = subject.parse('W0123 12:34:56.789       42 pkg/main4ever.go:123] "oh no"')
      expect(err).to be_nil
      expect(result.level).to eq(LogsParser::StructuredMessage::LEVEL_WARN)

      err, result = subject.parse('I0123 12:34:56.789       42 pkg/main4ever.go:123] "oh no"')
      expect(err).to be_nil
      expect(result.level).to eq(LogsParser::StructuredMessage::LEVEL_INFO)

      err, result = subject.parse('D0123 12:34:56.789       42 pkg/main4ever.go:123] "oh no"')
      expect(err).to be_nil
      expect(result.level).to eq(LogsParser::StructuredMessage::LEVEL_DEBUG)

      err, result = subject.parse('X0123 12:34:56.789       42 pkg/main4ever.go:123] "oh no"')
      expect(err).to be_nil
      expect(result.level).to eq('X')
    end

    context 'with header' do
      specify 'with display message' do
        err, result = subject.parse(%Q{E0123 12:34:56.789       42 pkg/main4ever.go:123] controller.main/func "oh no"})
        expect(err).to be_nil
        expect(result.properties['header']).to eq('controller.main/func')
        expect(result.display_message).to eq("oh no")
      end

      specify 'without display message' do
        err, result = subject.parse(%Q{E0123 12:34:56.789       42 pkg/main4ever.go:123] controller.main/func})
        expect(err).to be_nil
        expect(result.properties['header']).to eq('controller.main/func')
        expect(result.display_message).to be_nil
      end
    end

    context 'without header' do
      specify 'with display message' do
        err, result = subject.parse(%Q{E0123 12:34:56.789       42 pkg/main4ever.go:123] "oh no"})
        expect(err).to be_nil
        expect(result.display_message).to eq("oh no")
      end

      specify 'without display message' do
        err, result = subject.parse(%Q{E0123 12:34:56.789       42 pkg/main4ever.go:123]})
        expect(err).to be_nil
        expect(result.display_message).to be_nil
      end
    end

    specify 'with display message and properties' do
      err, result = subject.parse(%Q{E0123 12:34:56.789       42 pkg/main4ever.go:123] "oh no" a="x" b="y"})
      expect(err).to be_nil
      expect(result.display_message).to eq('oh no')
      expect(result.unparsed_raw).to eq('a="x" b="y"')
    end

    specify 'display message is parsed as JSON string' do
      err, result = subject.parse(%Q{E0123 12:34:56.789       42 pkg/main4ever.go:123] "something went wrong in \\"xvda0\\"\\nDisk full"})
      expect(err).to be_nil
      expect(result.display_message).to eq(%Q{something went wrong in "xvda0"\nDisk full})
    end

    specify 'ignoring spaces after header' do
      err, result = subject.parse(%Q{E0123 12:34:56.789       42 pkg/main4ever.go:123] controller.main/func  })
      expect(err).to be_nil
      expect(result.properties['header']).to eq('controller.main/func')
    end

    specify 'ignoring spaces after display message' do
      err, result = subject.parse(%Q{E0123 12:34:56.789       42 pkg/main4ever.go:123] "something went wrong in \\"xvda0\\"\\nDisk full"  })
      expect(err).to be_nil
      expect(result.display_message).to eq(%Q{something went wrong in "xvda0"\nDisk full})
    end
  end
end
