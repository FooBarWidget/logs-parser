# typed: true
# frozen_string_literal: true

require 'sorbet-runtime'
require_relative 'base'
require_relative '../structured_message'

module LogsParser
  module PostProcessor
    class DisplayMessage < Base
      KEYS = ['msg', 'message'].freeze

      sig { override.params(message: StructuredMessage).returns(T::Boolean) }
      def process(message)
        return false if message.display_message

        KEYS.each do |key|
          if dm = message.properties.fetch(key, nil)
            message.display_message = dm
            message.properties.delete(key)
            return true
          end
        end

        false
      end
    end
  end
end
