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
      expect(message.unparsed_remainder).to be_empty
    end

    specify 'property with string key' do
      message = new_message(%Q{"aa"="xx"})
      accepted, err = subject.parse(message)
      expect(accepted).to be true
      expect(err).to be_nil
      expect(message.properties['aa']).to eq('xx')
      expect(message.unparsed_remainder).to be_empty
    end

    specify 'property with keys that contain spaces' do
      message = new_message(%Q{time="2024-11-20T15:17:37Z" level=info msg="Maintenance repo complete" BSL name=default})
      accepted, err = subject.parse(message)
      expect(accepted).to be true
      expect(err).to be_nil
      expect(message.properties['BSL name']).to eq('default')
      expect(message.unparsed_remainder).to be_empty
    end

    specify 'property with keys that contain dots' do
      message = new_message(%Q{error="oh no" error.file="/go/manager.go:240"})
      accepted, err = subject.parse(message)
      expect(accepted).to be true
      expect(err).to be_nil
      expect(message.properties['error']).to eq('oh no')
      expect(message.properties['error.file']).to eq('/go/manager.go:240')
      expect(message.unparsed_remainder).to be_empty
    end

    specify 'property with string value' do
      message = new_message(%Q{aa="xx"})
      accepted, err = subject.parse(message)
      expect(accepted).to be true
      expect(err).to be_nil
      expect(message.properties['aa']).to eq('xx')
      expect(message.unparsed_remainder).to be_empty
    end

    specify 'property with primitive JSON values' do
      message = new_message(%Q{aa=true})
      accepted, err = subject.parse(message)
      expect(accepted).to be true
      expect(err).to be_nil
      expect(message.properties['aa']).to eq(true)
      expect(message.unparsed_remainder).to be_empty

      message = new_message(%Q{aa=123})
      accepted, err = subject.parse(message)
      expect(accepted).to be true
      expect(err).to be_nil
      expect(message.properties['aa']).to eq(123)
      expect(message.unparsed_remainder).to be_empty

      message = new_message(%Q{aa=123.5})
      accepted, err = subject.parse(message)
      expect(accepted).to be true
      expect(err).to be_nil
      expect(message.properties['aa']).to eq(123.5)
      expect(message.unparsed_remainder).to be_empty
    end

    specify 'property with complex JSON value' do
      message = new_message(%Q{aa={ "a": 1, "b": ["x", "y", 123.5, null], "c": true, "d": {}, "e": [] }})
      accepted, err = subject.parse(message)
      expect(accepted).to be true
      expect(err).to be_nil
      expect(message.properties['aa']).to eq({ 'a' => 1, 'b' => ['x', 'y', 123.5, nil], 'c' => true, 'd' => {}, 'e' => [] })
      expect(message.unparsed_remainder).to be_empty
    end

    specify 'property with serialized JSON value' do
      message = new_message(%Q{"namespaces"="{\\"exclude\\":[],\\"include\\":[]}"})
      accepted, err = subject.parse(message)
      expect(accepted).to be true
      expect(err).to be_nil
      expect(message.properties['namespaces']).to eq({ 'exclude' => [], 'include' => []})
      expect(message.unparsed_remainder).to be_empty
    end

    it 'property with value whose beginning looks like JSON' do
      message = new_message(%Q{item=1f22647-f3b5-4735-9996-765101b98e2d logSource=\"internal/delete/delete_item_action_handler.go:116\"})
      accepted, err = subject.parse(message)
      expect(accepted).to be true
      expect(err).to be_nil
      expect(message.properties['item']).to eq('1f22647-f3b5-4735-9996-765101b98e2d')
      expect(message.properties['logSource']).to eq('internal/delete/delete_item_action_handler.go:116')
      expect(message.unparsed_remainder).to be_empty

      message = new_message(%Q{item=1f22647-f3b5-4735-9996-765101b98e2d})
      accepted, err = subject.parse(message)
      expect(accepted).to be true
      expect(err).to be_nil
      expect(message.properties['item']).to eq('1f22647-f3b5-4735-9996-765101b98e2d')
      expect(message.unparsed_remainder).to be_empty
    end

    it 'does not parse zero-leading numbers as JSON' do
      message = new_message(%Q{name=021891576552})
      accepted, err = subject.parse(message)
      expect(accepted).to be true
      expect(err).to be_nil
      expect(message.properties['name']).to eq('021891576552')
    end

    specify 'property with empty literal value' do
      message = new_message(%Q{aa=})
      accepted, err = subject.parse(message)
      expect(accepted).to be true
      expect(err).to be_nil
      expect(message.properties['aa']).to eq('')
      expect(message.unparsed_remainder).to be_empty
    end

    specify 'property with non-empty literal value' do
      message = new_message(%Q{aa=bb})
      accepted, err = subject.parse(message)
      expect(accepted).to be true
      expect(err).to be_nil
      expect(message.properties['aa']).to eq('bb')
      expect(message.unparsed_remainder).to be_empty
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
      expect(message.unparsed_remainder).to be_empty
    end

    it 'ignores trailing spaces' do
      message = new_message(%Q{foo="bar"  })
      accepted, err = subject.parse(message)
      expect(accepted).to be true
      expect(err).to be_nil
      expect(message.properties['foo']).to eq('bar')
      expect(message.unparsed_remainder).to be_empty
    end

    it 'supports unicode values' do
      message = new_message(%Q{db_storage=2.018µs})
      accepted, err = subject.parse(message)
      expect(accepted).to be true
      expect(err).to be_nil
      expect(message.properties['db_storage']).to eq('2.018µs')
      expect(message.unparsed_remainder).to be_empty
    end
  end
end
