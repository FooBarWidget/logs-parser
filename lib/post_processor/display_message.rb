# typed: true
# frozen_string_literal: true

require 'sorbet-runtime'
require_relative 'base'
require_relative '../structured_message'

module LogsParser
  module PostProcessor
    class DisplayMessage < Base
      DISPLAY_MESSAGE_KEYS = ['msg', 'message'].freeze

      sig { override.params(message: StructuredMessage).returns(T.nilable(StructuredMessage)) }
      def process(message)
        return nil if message.display_message

        DISPLAY_MESSAGE_KEYS.each do |key|
          if dm = message.properties&.fetch(key)
            message = message.deep_dup
            message.display_message = dm
            T.must(message.properties).delete(key)
            return message
          end
        end

        nil
      end
    end
  end
end
