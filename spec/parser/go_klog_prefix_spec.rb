require_relative '../spec_helper'
require_relative '../../lib/parser/go_klog_prefix'

RSpec.describe LogsParser::Parser::GoKlogPrefix do
  describe '#parse' do
    subject { described_class.new }

    def new_message(raw)
      LogsParser::StructuredMessage.new(
        raw: raw,
        unparsed_remainder: raw,
        properties: {},
      )
    end

    specify 'standard metadata' do
      raw = 'E0123 12:34:56.789       42 pkg/main4ever.go:123] "oh no"'
      message = new_message(raw)
      accepted, err = subject.parse(message)
      expect(accepted).to be true
      expect(err).to be_nil
      expect(message).to have_attributes(
        level: LogsParser::StructuredMessage::LEVEL_ERROR,
        time: '12:34:56.789',
        raw: raw,
        unparsed_remainder: '',
        properties: {
          'code' => '0123',
          'source_file' => 'pkg/main4ever.go',
          'source_line' => 123,
        },
      )
    end

    specify 'invalid metadata' do
      message = new_message('E0123 12:34:56.789       42 pkg/main4ever.go:123')
      accepted, err = subject.parse(message)
      expect(accepted).to be false
      expect(err).to be_nil
    end

    specify 'log levels' do
      message = new_message('E0123 12:34:56.789       42 pkg/main4ever.go:123] "oh no"')
      accepted, err = subject.parse(message)
      expect(accepted).to be true
      expect(err).to be_nil
      expect(message.level).to eq(LogsParser::StructuredMessage::LEVEL_ERROR)

      message = new_message('W0123 12:34:56.789       42 pkg/main4ever.go:123] "oh no"')
      accepted, err = subject.parse(message)
      expect(accepted).to be true
      expect(err).to be_nil
      expect(message.level).to eq(LogsParser::StructuredMessage::LEVEL_WARN)

      message = new_message('I0123 12:34:56.789       42 pkg/main4ever.go:123] "oh no"')
      accepted, err = subject.parse(message)
      expect(accepted).to be true
      expect(err).to be_nil
      expect(message.level).to eq(LogsParser::StructuredMessage::LEVEL_INFO)

      message = new_message('D0123 12:34:56.789       42 pkg/main4ever.go:123] "oh no"')
      accepted, err = subject.parse(message)
      expect(accepted).to be true
      expect(err).to be_nil
      expect(message.level).to eq(LogsParser::StructuredMessage::LEVEL_DEBUG)

      message = new_message('X0123 12:34:56.789       42 pkg/main4ever.go:123] "oh no"')
      accepted, err = subject.parse(message)
      expect(accepted).to be true
      expect(err).to be_nil
      expect(message.level).to eq('X')
    end

    context 'with header' do
      specify 'with display message' do
        message = new_message(%Q{E0123 12:34:56.789       42 pkg/main4ever.go:123] controller.main/func "oh no"})
        accepted, err = subject.parse(message)
        expect(accepted).to be true
        expect(err).to be_nil
        expect(message.properties['header']).to eq('controller.main/func')
        expect(message.display_message).to eq("oh no")
      end

      specify 'without display message' do
        message = new_message(%Q{E0123 12:34:56.789       42 pkg/main4ever.go:123] controller.main/func})
        accepted, err = subject.parse(message)
        expect(accepted).to be true
        expect(err).to be_nil
        expect(message.properties['header']).to eq('controller.main/func')
        expect(message.display_message).to be_nil
      end
    end

    context 'without header' do
      specify 'with display message' do
        message = new_message(%Q{E0123 12:34:56.789       42 pkg/main4ever.go:123] "oh no"})
        accepted, err = subject.parse(message)
        expect(accepted).to be true
        expect(err).to be_nil
        expect(message.display_message).to eq("oh no")
      end

      specify 'without display message' do
        message = new_message(%Q{E0123 12:34:56.789       42 pkg/main4ever.go:123]})
        accepted, err = subject.parse(message)
        expect(accepted).to be true
        expect(err).to be_nil
        expect(message.display_message).to be_nil
      end
    end

    specify 'with display message and properties' do
      message = new_message(%Q{E0123 12:34:56.789       42 pkg/main4ever.go:123] "oh no" a="x" b="y"})
      accepted, err = subject.parse(message)
      expect(accepted).to be true
      expect(err).to be_nil
      expect(message.display_message).to eq('oh no')
      expect(message.unparsed_remainder).to eq('a="x" b="y"')
    end

    specify 'display message is parsed as JSON string' do
      message = new_message(%Q{E0123 12:34:56.789       42 pkg/main4ever.go:123] "something went wrong in \\"xvda0\\"\\nDisk full"})
      accepted, err = subject.parse(message)
      expect(accepted).to be true
      expect(err).to be_nil
      expect(message.display_message).to eq(%Q{something went wrong in "xvda0"\nDisk full})
    end

    specify 'ignoring spaces after header' do
      message = new_message(%Q{E0123 12:34:56.789       42 pkg/main4ever.go:123] controller.main/func  })
      accepted, err = subject.parse(message)
      expect(accepted).to be true
      expect(err).to be_nil
      expect(message.properties['header']).to eq('controller.main/func')
    end

    specify 'ignoring spaces after display message' do
      message = new_message(%Q{E0123 12:34:56.789       42 pkg/main4ever.go:123] "something went wrong in \\"xvda0\\"\\nDisk full"  })
      accepted, err = subject.parse(message)
      expect(accepted).to be true
      expect(err).to be_nil
      expect(message.display_message).to eq(%Q{something went wrong in "xvda0"\nDisk full})
    end
  end
end
