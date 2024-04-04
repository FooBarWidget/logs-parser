# typed: true
# frozen_string_literal: true

require 'sorbet-runtime'
require_relative '../structured_message'

module LogsParser
  module Parser
    class Base
      extend T::Sig
      extend T::Helpers
      abstract!

      sig { abstract.params(raw: String).returns(T.nilable(StructuredMessage)) }
      def parse(raw); end
    end
  end
end
