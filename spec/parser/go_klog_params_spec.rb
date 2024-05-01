require_relative '../spec_helper'
require_relative '../../lib/parser/go_klog_params'

RSpec.describe LogsParser::Parser::GoKlogParams do
  describe '#parse' do
    subject { described_class.new }

    specify 'property with literal key' do
      err, result = subject.parse(%Q{aa="xx"})
      expect(err).to be_nil
      expect(result.properties['aa']).to eq('xx')
    end

    specify 'property with string key' do
      err, result = subject.parse(%Q{"aa"="xx"})
      expect(err).to be_nil
      expect(result.properties['aa']).to eq('xx')
    end

    specify 'property with string value' do
      err, result = subject.parse(%Q{aa="xx"})
      expect(err).to be_nil
      expect(result.properties['aa']).to eq('xx')
    end

    specify 'property with primitive JSON values' do
      err, result = subject.parse(%Q{aa=true})
      expect(err).to be_nil
      expect(result.properties['aa']).to eq(true)

      err, result = subject.parse(%Q{aa=123})
      expect(err).to be_nil
      expect(result.properties['aa']).to eq(123)

      err, result = subject.parse(%Q{aa=123.5})
      expect(err).to be_nil
      expect(result.properties['aa']).to eq(123.5)
    end

    specify 'property with complex JSON value' do
      err, result = subject.parse(%Q{aa={ "a": 1, "b": ["x", "y", 123.5, null], "c": true, "d": {}, "e": [] }})
      expect(err).to be_nil
      expect(result.properties['aa']).to eq({ 'a' => 1, 'b' => ['x', 'y', 123.5, nil], 'c' => true, 'd' => {}, 'e' => [] })
    end

    specify 'property with serialized JSON value' do
      err, result = subject.parse(%Q{"namespaces"="{\\"exclude\\":[],\\"include\\":[]}"})
      expect(err).to be_nil
      expect(result.properties['namespaces']).to eq({ 'exclude' => [], 'include' => []})
    end

    specify 'property with empty literal value' do
      err, result = subject.parse(%Q{aa=})
      expect(err).to be_nil
      expect(result.properties['aa']).to eq('')
    end

    specify 'property with non-empty literal value' do
      err, result = subject.parse(%Q{aa=bb})
      expect(err).to be_nil
      expect(result.properties['aa']).to eq('bb')
    end

    specify 'multiple properties' do
      err, result = subject.parse(%Q{aa= bb= cc="xx" dd=123})
      expect(err).to be_nil
      expect(result.properties['aa']).to eq('')
      expect(result.properties['bb']).to eq('')
      expect(result.properties['cc']).to eq('xx')
      expect(result.properties['dd']).to eq(123)
    end

    it 'ignores trailing properties' do
      err, result = subject.parse(%Q{foo="bar"  })
      expect(err).to be_nil
      expect(result.properties['foo']).to eq('bar')
    end
  end
end
