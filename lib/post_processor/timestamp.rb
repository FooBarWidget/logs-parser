# typed: true
# frozen_string_literal: true

require 'sorbet-runtime'
require_relative 'base'
require_relative '../structured_message'

module LogsParser
  module PostProcessor
    class Timestamp < Base
      KEYS = ['ts'].freeze

      sig { override.params(message: StructuredMessage).returns(T::Boolean) }
      def process(message)
        # If there's a timestamp property then override the StructuredMessage's
        # native timestamp because the one in the property may be more accurate.
        KEYS.each do |key|
          if (value = message.properties.fetch(key)) && ((value.is_a?(String) && value =~ /\A[0-9]+(\.([0-9]+))?\Z/) || value.is_a?(Numeric))
            message.timestamp = Time.at(value.is_a?(Numeric) ? value : value.to_f)
            message.properties.delete(key)
            return true
          end
        end

        false
      end
    end
  end
end
