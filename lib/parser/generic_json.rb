# typed: true
# frozen_string_literal: true

require 'sorbet-runtime'
require 'json'
require_relative 'base'
require_relative '../structured_message'

module LogsParser
  module Parser
    class GenericJson < Base
      sig { override.params(raw: String).returns(T.nilable(StructuredMessage)) }
      def parse(raw)
        JSON.parse(raw)
      rescue JSON::ParserError
        nil
      end
    end
  end
end
