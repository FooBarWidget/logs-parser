# typed: true
# frozen_string_literal: true

require 'sorbet-runtime'
require_relative '../structured_message'

module LogsParser
  module Output
    class Base
      extend T::Sig
      extend T::Helpers
      abstract!

      sig { abstract.params(message: StructuredMessage).void }
      def write(message); end

      def close; end
    end
  end
end
