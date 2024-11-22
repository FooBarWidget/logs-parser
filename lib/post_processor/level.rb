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
          if value = message.properties.fetch(key, nil)
            message.level = normalize_level_string(value)
            message.properties.delete(key)
            return true
          end
        end

        false
      end

      private

      sig { params(level: String).returns(String) }
      def normalize_level_string(level)
        case level.downcase
        when 'debug'
          StructuredMessage::LEVEL_DEBUG
        when 'info'
          StructuredMessage::LEVEL_INFO
        when 'warning', 'warn'
          StructuredMessage::LEVEL_WARN
        when 'error', 'err', 'crit', 'critical', 'fatal'
          StructuredMessage::LEVEL_ERROR
        else
          level
        end
      end
    end
  end
end
