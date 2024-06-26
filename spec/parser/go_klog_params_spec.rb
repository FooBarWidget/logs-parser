require_relative '../spec_helper'
require_relative '../../lib/parser/go_klog_params'

RSpec.describe LogsParser::Parser::GoKlogParams do
  describe '#parse' do
    subject { described_class.new }

    def new_message(raw)
      LogsParser::StructuredMessage.new(
        raw: raw,
        unparsed_remainder: raw,
        properties: {},
      )
    end

    specify 'property with literal key' do
      message = new_message(%Q{aa="xx"})
      accepted, err = subject.parse(message)
      expect(accepted).to be true
      expect(err).to be_nil
      expect(message.properties['aa']).to eq('xx')
    end

    specify 'property with string key' do
      message = new_message(%Q{"aa"="xx"})
      accepted, err = subject.parse(message)
      expect(accepted).to be true
      expect(err).to be_nil
      expect(message.properties['aa']).to eq('xx')
    end

    specify 'property with string value' do
      message = new_message(%Q{aa="xx"})
      accepted, err = subject.parse(message)
      expect(accepted).to be true
      expect(err).to be_nil
      expect(message.properties['aa']).to eq('xx')
    end

    specify 'property with primitive JSON values' do
      message = new_message(%Q{aa=true})
      accepted, err = subject.parse(message)
      expect(accepted).to be true
      expect(err).to be_nil
      expect(message.properties['aa']).to eq(true)

      message = new_message(%Q{aa=123})
      accepted, err = subject.parse(message)
      expect(accepted).to be true
      expect(err).to be_nil
      expect(message.properties['aa']).to eq(123)

      message = new_message(%Q{aa=123.5})
      accepted, err = subject.parse(message)
      expect(accepted).to be true
      expect(err).to be_nil
      expect(message.properties['aa']).to eq(123.5)
    end

    specify 'property with complex JSON value' do
      message = new_message(%Q{aa={ "a": 1, "b": ["x", "y", 123.5, null], "c": true, "d": {}, "e": [] }})
      accepted, err = subject.parse(message)
      expect(accepted).to be true
      expect(err).to be_nil
      expect(message.properties['aa']).to eq({ 'a' => 1, 'b' => ['x', 'y', 123.5, nil], 'c' => true, 'd' => {}, 'e' => [] })
    end

    specify 'property with serialized JSON value' do
      message = new_message(%Q{"namespaces"="{\\"exclude\\":[],\\"include\\":[]}"})
      accepted, err = subject.parse(message)
      expect(accepted).to be true
      expect(err).to be_nil
      expect(message.properties['namespaces']).to eq({ 'exclude' => [], 'include' => []})
    end

    specify 'property with empty literal value' do
      message = new_message(%Q{aa=})
      accepted, err = subject.parse(message)
      expect(accepted).to be true
      expect(err).to be_nil
      expect(message.properties['aa']).to eq('')
    end

    specify 'property with non-empty literal value' do
      message = new_message(%Q{aa=bb})
      accepted, err = subject.parse(message)
      expect(accepted).to be true
      expect(err).to be_nil
      expect(message.properties['aa']).to eq('bb')
    end

    specify 'multiple properties' do
      message = new_message(%Q{aa= bb= cc="xx" dd=123})
      accepted, err = subject.parse(message)
      expect(accepted).to be true
      expect(err).to be_nil
      expect(message.properties['aa']).to eq('')
      expect(message.properties['bb']).to eq('')
      expect(message.properties['cc']).to eq('xx')
      expect(message.properties['dd']).to eq(123)
    end

    it 'ignores trailing properties' do
      message = new_message(%Q{foo="bar"  })
      accepted, err = subject.parse(message)
      expect(accepted).to be true
      expect(err).to be_nil
      expect(message.properties['foo']).to eq('bar')
    end
  end
end
