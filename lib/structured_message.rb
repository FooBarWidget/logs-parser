# typed: true
# frozen_string_literal: true

require 'sorbet-runtime'

module LogsParser
  class StructuredMessage < T::Struct
    extend T::Sig

    MAX_LEVEL_KEY_SIZE = 5
    LEVEL_ERROR = "error"
    LEVEL_WARN = "warn"
    LEVEL_INFO = "info"
    LEVEL_DEBUG = "debug"

    prop :timestamp, T.nilable(Time)
    prop :time, T.nilable(String)
    prop :level, T.nilable(String)
    prop :display_message, T.nilable(String)
    prop :properties, T.nilable(T::Hash[String, T.untyped])
    prop :raw, String
    # Part of the raw message that has been unparsed and that can be fed to the next parser.
    prop :unparsed_raw, T.nilable(String)

    sig { params(other: StructuredMessage).returns(StructuredMessage) }
    def merge(other)
      StructuredMessage.new(
        timestamp: other.timestamp || timestamp,
        time: other.time || time,
        level: other.level || level,
        display_message: other.display_message || display_message,
        properties:
          (properties.nil? && other.properties.nil?) ?
          nil :
          (properties || {}).merge(other.properties || {}),

          raw: other.raw,
        unparsed_raw: other.unparsed_raw,
      )
    end

    sig { returns(StructuredMessage) }
    def deep_dup
      T.cast(Marshal.load(Marshal.dump(self)), StructuredMessage)
    end
  end
end
