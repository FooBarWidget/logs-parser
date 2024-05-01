# typed: true
# frozen_string_literal: true

require 'sorbet-runtime'
require_relative '../structured_message'

module LogsParser
  module PostProcessor
    class Base
      extend T::Sig
      extend T::Helpers
      abstract!

      sig { abstract.params(message: StructuredMessage).returns(T.nilable(StructuredMessage)) }
      def process(message); end
    end
  end
end
