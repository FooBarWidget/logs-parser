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
        params(raw: String).
        returns([
          T.nilable(ParseError),
          T.nilable(StructuredMessage),
        ])
      end
      def parse(raw)
        doc = JSON.parse(raw)
        message = StructuredMessage.new(
          properties: doc,
          raw: raw,
        )
        [nil, message]
      rescue JSON::ParserError
        [nil, nil]
      end
    end
  end
end
