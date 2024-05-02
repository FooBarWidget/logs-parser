# typed: true
# frozen_string_literal: true

require 'sorbet-runtime'
require 'json'
require_relative 'base'
require_relative '../structured_message'

module LogsParser
  module Parser
    class GenericJson < Base
      sig do
        override.
        params(message: StructuredMessage).
        returns([
          T::Boolean,
          T.nilable(ParseError),
        ])
      end
      def parse(message)
        doc = JSON.parse(message.unparsed_remainder)
        message.unparsed_remainder = ""
        message.properties.merge!(doc)
        [true, nil]
      rescue JSON::ParserError
        [false, nil]
      end
    end
  end
end
