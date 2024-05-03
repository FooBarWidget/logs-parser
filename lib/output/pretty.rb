# typed: true
# frozen_string_literal: true

require 'sorbet-runtime'
require 'neatjson'
require 'time'
require_relative 'base'

module LogsParser
  module Output
    class Pretty < Base
      ANSI_COLOR_RED = "\033[31m"
      ANSI_COLOR_YELLOW = "\033[33m"
      ANSI_COLOR_BLUE = "\033[34m"
      ANSI_COLOR_GRAY = "\033[38;5;246m"
      ANSI_COLOR_RESET = "\033[0m"

      sig { override.params(message: StructuredMessage).void }
      def write(message)
        STDOUT.puts(format(message))
        STDOUT.flush
      end

      private

      sig { params(message: StructuredMessage).returns(String) }
      def format(message)
        result = colorize([
          format_column(value: message.level, default: "<NOLEVEL>", min_length: StructuredMessage::MAX_LEVEL_KEY_SIZE),
          format_column(value: message.timestamp&.iso8601(3) || message.time, default: "<NOTIMESTAMP>", min_length: 25),
          format_column(value: message.display_message, default: "<No display message>"),
        ].join("  "), color_for_level(message.level))

        max_key_size = message.properties.keys.max_by(&:size)&.size || 0
        message.properties.each do |key, value|
          base_indent = " " * (StructuredMessage::MAX_LEVEL_KEY_SIZE + 2 + 25 + 2 + 4)
          result << "\n"
          result << ANSI_COLOR_GRAY
          result << base_indent
          result << key.ljust(max_key_size)
          result << " : "
          if value.is_a?(Array) || value.is_a?(Hash)
            result << indent_secondary_lines(
              ::JSON.neat_generate(value, wrap: 40, padding: 1, after_colon: 1, after_comma: 1),
              # Prefix every indented line with ANSI color code in
              # order to support viewing the output in 'less -R':
              # 'less -R' resets the line color after every newline.
              ANSI_COLOR_GRAY + " " * (base_indent.size + max_key_size + 3),
            )
          else
            result << value.to_s
          end
          result << ANSI_COLOR_RESET
        end

        result
      end

      def format_column(value:, default: nil, min_length: nil)
        value ||= default || ""
        if min_length
          value = value.ljust(min_length)
        end
        value
      end

      def color_for_level(level)
        case level
        when StructuredMessage::LEVEL_ERROR
          ANSI_COLOR_RED
        when StructuredMessage::LEVEL_WARN
          ANSI_COLOR_YELLOW
        when StructuredMessage::LEVEL_INFO
          ANSI_COLOR_BLUE
        when StructuredMessage::LEVEL_DEBUG
          ANSI_COLOR_GRAY
        else
          nil
        end
      end

      def colorize(text, color)
        if color
          "#{color}#{text}#{ANSI_COLOR_RESET}"
        else
          text
        end
      end

      def indent_secondary_lines(text, indent)
        lines = text.split("\n")
        return text if lines.size <= 1

        secondary_lines = lines[1 .. -1]
        secondary_lines.map! do |line|
          indent + line
        end
        lines[0] + "\n" + secondary_lines.join("\n")
      end
    end
  end
end
