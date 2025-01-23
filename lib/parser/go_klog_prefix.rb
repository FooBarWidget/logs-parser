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
    # Parses the metadata, header and display message part of a klog-like message. Something like:
    #
    #   I0123 12:34:56.789012   12345 file.go:67] Event occurred foo="bar"
    #   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    #                       only this part
    #
    # Does not parse the key-value properties. For that, see GoKlogParams.
    #
    # The reason why we split things up is because there are multiple variants of klog-like messages.
    #
    # More info about klog:
    # https://kubernetes.io/docs/concepts/cluster-administration/system-logs/
    # https://github.com/kubernetes/klog/tree/main/textlogger
    class GoKlogPrefix < Base
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

        accepted, header, display_message, params, err = parse_structured_payload(payload, message.properties)
        return [true, err] if err

        if accepted
          message.properties["header"] = header if header
          message.display_message = display_message if display_message
          message.unparsed_remainder = params
        else
          message.display_message = payload
          message.unparsed_remainder = ""
        end

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
        params(payload: String, properties: T::Hash[String, T.untyped]).
        returns([
          # Whether the payload was recognized as structured
          T::Boolean,
          # Header
          T.nilable(String),
          # Display message
          T.nilable(String),
          # Klog key-value parameters as a string, may be empty
          String,
          T.nilable(ParseError),
        ])
      end
      def parse_structured_payload(payload, properties)
        pos = 0

        # Scan optional header
        if payload[pos] != "\""
          err, header, header_charsize = scan_literal(payload)
          return [true, nil, nil, "", ParseError.new("Error scanning header: #{err.message}")] if err
          if !header.empty?
            if payload[pos + header_charsize] == "="
              # This is not actually a header but a key-value pair. Unscan this.
              header = ""
            else
              pos += header_charsize

              # Skip spaces
              pos += 1 while payload[pos] == ' '
            end
          end
        else
          header = ""
        end

        # Scan optional display message
        err, display_message, display_message_charsize = scan_and_parse_json_string_or_literal(T.must(payload[pos .. -1]))
        return [true, nil, nil, "", ParseError.new("Error parsing display message: #{err.message}")] if err
        if !display_message.empty?
          if payload[pos + display_message_charsize] == "="
            # This is not actually a display message but a key-value pair. Unscan this.
            display_message = ""
          else
            pos += display_message_charsize

            # Skip spaces
            pos += 1 while payload[pos] == ' '
          end
        end

        # Scan key-value parameters.
        params_data = T.must(payload[pos .. -1])
        if params_data.empty?
          return [
            true,
            header.empty? ? nil : header,
            display_message.empty? ? nil : display_message,
            params_data,
            nil,
          ]
        end

        err, properties, ncharsconsumed = scan_and_parse_kv_params(params_data, pos, support_unquoted_sentences: false)
        if err || ncharsconsumed == 0
          [
            false,
            nil,
            nil,
            "",
            nil,
          ]
        else
          [
            true,
            header.empty? ? nil : header,
            display_message.empty? ? nil : display_message,
            params_data,
            nil,
          ]
        end
      end
    end
  end
end
