# typed: true
# frozen_string_literal: true

require 'sorbet-runtime'

module LogsParser
  class StructuredMessage < T::Struct
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
  end
end
