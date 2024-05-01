# typed: true
# frozen_string_literal: true

require 'sorbet-runtime'
require_relative '../structured_message'

module LogsParser
  class ParseError < StandardError; end

  module Parser
    class Base
      extend T::Sig
      extend T::Helpers
      abstract!

      sig do
        abstract.
        params(raw: String).
        returns([
          # A ParseError occurs if this parser believes it can parse the message,
          # but it is malformed. Such errors should be reported to the user.
          T.nilable(ParseError),
          # If there was no ParseError then this parser can still believe
          # it cannot parse this message. A different parser should be tried.
          T.nilable(StructuredMessage),
        ])
      end
      def parse(raw); end
    end
  end
end
