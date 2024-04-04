require_relative '../spec_helper'
require_relative '../../lib/parsers/go_log'

RSpec.describe LogsParser::Parser::GoLog do
  describe '#parse' do
    subject { described_class.new }

    specify 'standard metadata' do
      raw = 'E0123 12:34:56.789       42 pkg/main4ever.go:123] "oh no"'
      expect(subject.parse(raw)).to have_attributes(
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
      result = subject.parse('E0123 12:34:56.789       42 pkg/main4ever.go:123')
      expect(result).to be_nil
    end

    specify 'log levels' do
      result = subject.parse('E0123 12:34:56.789       42 pkg/main4ever.go:123] "oh no"')
      expect(result.level).to eq(LogsParser::StructuredMessage::LEVEL_ERROR)

      result = subject.parse('W0123 12:34:56.789       42 pkg/main4ever.go:123] "oh no"')
      expect(result.level).to eq(LogsParser::StructuredMessage::LEVEL_WARN)

      result = subject.parse('I0123 12:34:56.789       42 pkg/main4ever.go:123] "oh no"')
      expect(result.level).to eq(LogsParser::StructuredMessage::LEVEL_INFO)

      result = subject.parse('D0123 12:34:56.789       42 pkg/main4ever.go:123] "oh no"')
      expect(result.level).to eq(LogsParser::StructuredMessage::LEVEL_DEBUG)

      result = subject.parse('X0123 12:34:56.789       42 pkg/main4ever.go:123] "oh no"')
      expect(result.level).to eq('X')
    end

    context 'with component' do
      specify 'with display message' do
        result = subject.parse(%Q{E0123 12:34:56.789       42 pkg/main4ever.go:123] controller.main/func "oh no"})
        expect(result.properties['component']).to eq('controller.main/func')
        expect(result.display_message).to eq("oh no")
      end

      specify 'without display message' do
        result = subject.parse(%Q{E0123 12:34:56.789       42 pkg/main4ever.go:123] controller.main/func})
        expect(result.properties['component']).to eq('controller.main/func')
        expect(result.display_message).to be_nil
      end
    end

    context 'without component' do
      specify 'with display message' do
        result = subject.parse(%Q{E0123 12:34:56.789       42 pkg/main4ever.go:123] "oh no"})
        expect(result.display_message).to eq("oh no")
      end

      specify 'without display message' do
        result = subject.parse(%Q{E0123 12:34:56.789       42 pkg/main4ever.go:123]})
        expect(result.display_message).to be_nil
      end
    end

    specify 'with display message and properties' do
      result = subject.parse(%Q{E0123 12:34:56.789       42 pkg/main4ever.go:123] "oh no" a="x" b="y"})
      expect(result.display_message).to eq('oh no')
      expect(result.properties['a']).to eq('x')
      expect(result.properties['b']).to eq('y')
    end

    specify 'display message is parsed as JSON string' do
      result = subject.parse(%Q{E0123 12:34:56.789       42 pkg/main4ever.go:123] "something went wrong in \\"xvda0\\"\\nDisk full"})
      expect(result.display_message).to eq(%Q{something went wrong in "xvda0"\nDisk full})
    end

    specify 'property with literal key' do
      result = subject.parse(%Q{E0123 12:34:56.789       42 pkg/main4ever.go:123] "oh no" aa="xx"})
      expect(result.properties['aa']).to eq('xx')
    end

    specify 'property with string key' do
      result = subject.parse(%Q{E0123 12:34:56.789       42 pkg/main4ever.go:123] "oh no" "aa"="xx"})
      expect(result.properties['aa']).to eq('xx')
    end

    specify 'property with string value' do
      result = subject.parse(%Q{E0123 12:34:56.789       42 pkg/main4ever.go:123] "oh no" aa="xx"})
      expect(result.properties['aa']).to eq('xx')
    end

    specify 'property with primitive JSON values' do
      result = subject.parse(%Q{E0123 12:34:56.789       42 pkg/main4ever.go:123] "oh no" aa=true})
      expect(result.properties['aa']).to eq(true)

      result = subject.parse(%Q{E0123 12:34:56.789       42 pkg/main4ever.go:123] "oh no" aa=123})
      expect(result.properties['aa']).to eq(123)

      result = subject.parse(%Q{E0123 12:34:56.789       42 pkg/main4ever.go:123] "oh no" aa=123.5})
      expect(result.properties['aa']).to eq(123.5)
    end

    specify 'property with complex JSON value' do
      result = subject.parse(%Q{E0123 12:34:56.789       42 pkg/main4ever.go:123] "oh no" aa={ "a": 1, "b": ["x", "y", 123.5, null], "c": true, "d": {}, "e": [] }})
      expect(result.properties['aa']).to eq({ 'a' => 1, 'b' => ['x', 'y', 123.5, nil], 'c' => true, 'd' => {}, 'e' => [] })
    end

    specify 'property with serialized JSON value' do
      result = subject.parse(%Q{I0403 12:50:24.991485       1 metricsconfig.go:138] config "namespaces"="{\\"exclude\\":[],\\"include\\":[]}"})
      expect(result.properties['namespaces']).to eq({ 'exclude' => [], 'include' => []})
    end

    specify 'property with empty literal value' do
      result = subject.parse(%Q{E0123 12:34:56.789       42 pkg/main4ever.go:123] "oh no" aa=})
      expect(result.properties['aa']).to eq('')
    end

    specify 'multiple properties' do
      result = subject.parse(%Q{E0123 12:34:56.789       42 pkg/main4ever.go:123] "oh no" aa= bb= cc="xx"})
      expect(result.properties['aa']).to eq('')
      expect(result.properties['bb']).to eq('')
      expect(result.properties['cc']).to eq('xx')
    end

    specify 'ignoring spaces after component' do
      result = subject.parse(%Q{E0123 12:34:56.789       42 pkg/main4ever.go:123] controller.main/func  })
      expect(result.properties['component']).to eq('controller.main/func')
    end

    specify 'ignoring spaces after display message' do
      result = subject.parse(%Q{E0123 12:34:56.789       42 pkg/main4ever.go:123] "something went wrong in \\"xvda0\\"\\nDisk full"  })
      expect(result.display_message).to eq(%Q{something went wrong in "xvda0"\nDisk full})
    end

    specify 'ignoring spaces after properties' do
      result = subject.parse(%Q{E0123 12:34:56.789       42 pkg/main4ever.go:123] foo="bar"  })
      expect(result.properties['foo']).to eq('bar')
    end
  end
end
