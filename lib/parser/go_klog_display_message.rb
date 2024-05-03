# typed: true
# frozen_string_literal: true

require 'sorbet-runtime'
require 'strscan'
require 'json'
require_relative 'base'
require_relative 'go_klog_helper'
require_relative '../structured_message'

module LogsParser
  module Parser
    # Parses the header and display message part of a klog-like message. Something like:
    #
    #   I0123 12:34:56.789012   12345 file.go:67] Event occurred
    #   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    #                only this part
    #
    # Does not parse:
    # - The header and display message.For that, see KlogDisplayMessage.
    # - The key-value properties. For that, see GoKlogParams.
    #
    # The reason why we split things up is because there are multiple variants of klog-like messages.
    #
    # More info about klog:
    # https://kubernetes.io/docs/concepts/cluster-administration/system-logs/
    # https://github.com/kubernetes/klog/tree/main/textlogger
    class GoKlogDisplayMessage < Base
      sig do
        override.
        params(message: StructuredMessage).
        returns([
          T::Boolean,
          T.nilable(ParseError),
        ])
      end
      def parse(message)
        return [false, nil] if message.unparsed_remainder !~ /^([A-Z])([0-9]+) ([0-9][0-9]:[0-9][0-9]:[0-9][0-9]\.[0-9]+)       [0-9]+ (\S+\.go):([0-9]+)\] *(.*)/

        level = T.let($1, String)
        code = T.let($2, String)
        time = T.let($3, String)
        source_file = T.let($4, String)
        source_line = T.let($5, String)
        payload = T.let($6, String)

        message.level = parse_level(level)
        message.time = time
        message.properties["code"] = code
        message.properties["source_file"] = source_file
        message.properties["source_line"] = source_line.to_i

        err, header, display_message, params = parse_payload(payload)
        return [true, err] if err

        message.properties["header"] = header if header
        message.display_message = display_message if display_message
        message.unparsed_remainder = params || ""

        [true, nil]
      end

      private

      include GoKlogHelper

      def parse_level(level)
        case level
        when "E"
          StructuredMessage::LEVEL_ERROR
        when "W"
          StructuredMessage::LEVEL_WARN
        when "I"
          StructuredMessage::LEVEL_INFO
        when "D"
          StructuredMessage::LEVEL_DEBUG
        else
          level
        end
      end

      sig do
        params(payload: String).
        returns([
          T.nilable(ParseError),
          # Header
          T.nilable(String),
          # Display message
          T.nilable(String),
          # Klog key-value parameters as a string
          T.nilable(String),
        ])
      end
      def parse_payload(payload)
        pos = 0

        # Scan optional header
        if payload[pos] != "\""
          err, header, header_size = scan_literal(payload)
          return [ParseError.new("Error scanning header: #{err.message}"), nil, nil, nil] if err
          if !header.empty?
            if payload[pos + header_size] == "="
              # This is not actually a header but a key-value pair. Unscan this.
              header = ""
            else
              pos += header_size

              # Skip spaces
              pos += 1 while payload[pos] == ' '
            end
          end
        else
          header = ""
        end

        # Scan optional display message
        err, display_message, display_message_size = scan_and_parse_json_string_or_literal(T.must(payload[pos .. -1]))
        return [ParseError.new("Error parsing display message: #{err.message}"), nil, nil, nil] if err
        if !display_message.empty?
          if payload[pos + display_message_size] == "="
            # This is not actually a main message but a key-value pair. Unscan this.
            display_message = ""
          else
            pos += display_message_size

            # Skip spaces
            pos += 1 while payload[pos] == ' '
          end
        end

        params = T.must(payload[pos .. -1])

        [
          nil,
          header.empty? ? nil : header,
          display_message.empty? ? nil : display_message,
          params.empty? ? nil : params,
        ]

        # if display_message.empty? && properties.key?("msg")
        #   display_message = properties.delete("msg")
        # end
      end

      if ENV['DEBUG'] == '1'
        def debug(message)
          puts "!!! #{message}"
        end
      else
        def debug(_message); end
      end
    end
  end
end
