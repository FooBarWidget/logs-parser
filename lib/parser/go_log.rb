# typed: true
# frozen_string_literal: true

require 'sorbet-runtime'
require 'strscan'
require 'json'
require_relative 'base'
require_relative '../structured_message'

module LogsParser
  module Parser
    class GoLog < Base
      sig { override.params(raw: String).returns(T.nilable(StructuredMessage)) }
      def parse(raw)
        return if raw !~ /^([A-Z])([0-9]+) ([0-9][0-9]:[0-9][0-9]:[0-9][0-9]\.[0-9]+)       [0-9]+ (\S+\.go):([0-9]+)\] ?(.*)/

        level = $1
        code = $2
        time = $3
        source_file = $4
        source_line = $5
        payload = $6

        result = StructuredMessage.new(
          level: parse_level(level),
          raw: raw,
          time: time,
          properties: {
            "code" => code,
            "source_file" => source_file,
            "source_line" => source_line.to_i,
          },
        )

        ok, display_message, parsed_properties = parse_payload(payload)
        if ok
          result.display_message = display_message
          T.must(result.properties).merge!(parsed_properties)
        else
          result.display_message = payload
        end

        result
      end

      private

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

      # Input payload: "Event occurred" object="container-registry-enforce" kind="ClusterPolicy"
      # Output: [true, "Event occurred", { "object" => "container-registry-enforce", "kind" => "ClusterPolicy" }]
      sig do
        params(payload: String).
        returns([
          T::Boolean,
          T.nilable(String),
          T::Hash[String, T.untyped],
        ])
      end
      def parse_payload(payload)
        pos = 0

        # Scan optional component identifier
        if payload[pos] != "\""
          component, component_size = scan_literal(payload)
          if !component.empty?
            if payload[pos + component_size] == "="
              # This is not actually a component identifier but a key-value pair. Unscan this.
              component = ""
            else
              pos += component_size

              # Skip spaces
              pos += 1 while payload[pos] == ' '
            end
          end
        else
          component = ""
        end

        # Scan optional display message
        display_message, display_message_size = scan_and_parse_json_string_or_literal(T.must(payload[pos .. -1]))
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

        # Scan key-value pairs
        properties = {}
        while pos < payload.size
          # Scan key
          key, key_size = scan_and_parse_json_string_or_literal(T.must(payload[pos .. -1]))
          if key.empty?
            debug "Failed to scan key at position #{pos} in payload"
            return false, nil, {}
          end
          pos += key_size

          # Scan delimiter
          if payload[pos] != '='
            debug "Failed to scan delimiter at position #{pos} in payload"
            return false, nil, {}
          end
          pos += 1

          # Scan value
          if payload[pos] == ' ' || payload[pos].nil?
            value = ""
          else
            value, value_size = scan_json(T.must(payload[pos .. -1]))
            value = JSON.parse(value)
            if value.is_a?(String)
              # May be a serialized JSON document. Try parsing it, but it's
              # fine if that fails.
              begin
                value = JSON.parse(value)
              rescue JSON::ParserError
              end
            end
            pos += value_size
          end

          properties[key] = value
          # Skip spaces
          pos += 1 while payload[pos] == ' '
        end

        properties["component"] = component if !component.empty?
        if display_message.empty? && properties.key?("msg")
          display_message = properties.delete("msg")
        end

        [true, display_message.empty? ? nil : display_message, properties]
      end

      sig { params(data: String).returns([String, Integer]) }
      def scan_json(data)
        if data[0] == "["
          scan_json_array(data)
        elsif data[0] == "{"
          scan_json_object(data)
        else
          scan_json_primitive(data)
        end
      end

      sig { params(data: String).returns([String, Integer]) }
      def scan_json_array(data)
        scanner = StringScanner.new(data)
        raise JSON::ParserError, "Invalid JSON array encountered: no opening bracket" if !scanner.skip("[")
        scanner.skip(/\s+/)

        while true
          if scanner.skip("]")
            return [T.must(data[0 .. scanner.pos - 1]), scanner.pos]
          elsif scanner.eos?
            raise JSON::ParserError, "Invalid JSON array encountered: no closing bracket"
          end

          elem, consumed_size = scan_json(scanner.rest)
          scanner.pos += consumed_size
          scanner.skip(/\s+/)
          scanner.skip(",")
          scanner.skip(/\s+/)
        end
      end

      sig { params(data: String).returns([String, Integer]) }
      def scan_json_object(data)
        scanner = StringScanner.new(data)
        raise JSON::ParserError, "Invalid JSON object encountered: no opening brace" if !scanner.skip("{")
        scanner.skip(/\s+/)

        while true
          if scanner.skip("}")
            return [T.must(data[0 .. scanner.pos - 1]), scanner.pos]
          elsif scanner.eos?
            raise JSON::ParserError, "Invalid JSON object encountered: no opening brace"
          end

          key, key_size = scan_json_string(scanner.rest)
          scanner.pos += key_size

          scanner.skip(/\s+/)
          raise JSON::ParserError, "Invalid JSON object encountered: no delimiter after key #{key.inspect}" if !scanner.skip(":")
          scanner.skip(/\s+/)

          value, value_size = scan_json(scanner.rest)
          scanner.pos += value_size

          scanner.skip(/\s+/)
          scanner.skip(",")
          scanner.skip(/\s+/)
        end
      end

      sig { params(data: String).returns([String, Integer]) }
      def scan_json_primitive(data)
        scanner = StringScanner.new(data)
        if (consumed = scanner.scan(/([0-9\.]+|true|false|null)/))
          [consumed, scanner.pos]
        elsif scanner.match?('"')
          scan_json_string(data)
        else
          raise JSON::ParserError, "Invalid JSON primitive encountered"
        end
      end

      sig { params(data: String).returns([String, Integer]) }
      def scan_and_parse_json_string_or_literal(data)
        if data[0] == '"'
          consumed, size = scan_json_string(data)
          [JSON.parse(consumed), size]
        else
          scan_literal(data)
        end
      end

      sig { params(data: String).returns([String, Integer]) }
      def scan_json_string(data)
        scanner = StringScanner.new(data)
        raise JSON::ParserError, "Invalid JSON string encountered: missing opening quote" if scanner.skip('"').nil?

        done = T.let(false, T::Boolean)
        consumed = String.new(encoding: Encoding::UTF_8, capacity: data.size)
        consumed << '"'
        while true
          locally_consumed = scanner.scan_until(/[\\"]/)

          case locally_consumed[-1]
          when '"'
            # Closing quote encountered
            consumed << locally_consumed[0 .. -1]
            return [consumed, scanner.pos]
          when "\\"
            # Consume escape sequence
            consumed << locally_consumed[0 .. -1]
            raise JSON::ParserError, "Invalid escape sequence encountered in JSON string" if scanner.eos?
            consumed << scanner.getch
            raise JSON::ParserError, "Invalid JSON string encountered: missing closing quote" if scanner.eos?
          when nil
            raise JSON::ParserError, "Invalid JSON string encountered: missing closing quote"
          else
            raise "BUG: impossible branch"
          end
        end
      end

      sig { params(data: String).returns([String, Integer]) }
      def scan_literal(data)
        scanner = StringScanner.new(data)
        consumed = scanner.scan_until(/(:?=|\s|\Z)/)
        if consumed[-1] =~ /[=\s]/
          [T.must(consumed[0 .. -2]), scanner.pos - 1]
        else
          [T.must(consumed[0 .. -1]), scanner.pos]
        end
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
