# typed: true
# frozen_string_literal: true

require 'sorbet-runtime'
require_relative 'base'
require_relative '../structured_message'

module LogsParser
  module PostProcessor
    class Timestamp < Base
      KEYS = ['ts', 'time'].freeze
      NUMERIC_REGEX = /\A[0-9]+(\.([0-9]+))?\Z/.freeze
      ISO8604_TIMESTAMP_REGEX = /\A[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?(Z|\+[0-9]{2}:[0-9]{2})\Z/.freeze

      sig { override.params(message: StructuredMessage).returns(T::Boolean) }
      def process(message)
        # If there's a timestamp property then override the StructuredMessage's
        # native timestamp because the one in the property may be more accurate.
        KEYS.each do |key|
          if value = message.properties.fetch(key, nil)
            if value.is_a?(String)
              if value =~ NUMERIC_REGEX
                message.timestamp = Time.at(value.to_f)
                message.properties.delete(key)
                return true
              elsif value =~ ISO8604_TIMESTAMP_REGEX
                message.timestamp = Time.parse(value)
                message.properties.delete(key)
                return true
              end
            elsif value.is_a?(Numeric)
              message.timestamp = Time.at(value)
              message.properties.delete(key)
              return true
            end
          end
        end

        false
      end
    end
  end
end
