# typed: true
# frozen_string_literal: true

require 'sorbet-runtime'
require 'json'
require_relative 'base'

module LogsParser
  module Output
    class JSON < Base
      sig { override.params(message: StructuredMessage).void }
      def write(message)
        STDOUT.puts(serialize(message))
        STDOUT.flush
      end

      private

      sig { params(message: StructuredMessage).returns(String) }
      def serialize(message)
        result = {}
        if message.timestamp
          result['@timestamp'] = message.timestamp&.iso8601
        elsif message.time
          result['@time'] = message.time
        end
        result['@level'] = message.level if message.level
        result['@message'] = message.display_message if message.display_message
        result.merge!(T.must(message.properties)) if message.properties
        result

        ::JSON.generate(result)
      end
    end
  end
end
