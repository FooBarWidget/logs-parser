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
        params(message: StructuredMessage).
        returns([
          # Whether the parser accepted the message.
          T::Boolean,
          # Occurs if this parser accepted the message, but found out it's
          # malformed. Such errors should be reported to the user.
          # If non-nil, the first element of the return value is true.
          T.nilable(ParseError),
        ])
      end
      def parse(message); end
    end
  end
end
