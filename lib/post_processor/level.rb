# typed: true
# frozen_string_literal: true

require 'sorbet-runtime'
require_relative 'base'
require_relative '../structured_message'

module LogsParser
  module PostProcessor
    class Level < Base
      KEYS = ['level'].freeze

      sig { override.params(message: StructuredMessage).returns(T::Boolean) }
      def process(message)
        # If there's a level property then override the StructuredMessage's
        # native level because the one in the property may be more accurate.
        KEYS.each do |key|
          if value = message.properties.fetch(key)
            message.level = value
            message.properties.delete(key)
            return true
          end
        end

        false
      end
    end
  end
end
