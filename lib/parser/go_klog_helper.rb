# typed: true
# frozen_string_literal: true

require 'sorbet-runtime'
require 'strscan'
require 'json'
require_relative 'base'

module LogsParser
  module Parser
    # Helper functions for parsing klog messages, shared between GoKlogText and GoKlogParams.
    #
    # https://kubernetes.io/docs/concepts/cluster-administration/system-logs/
    # https://github.com/kubernetes/klog/tree/main/textlogger
    module GoKlogHelper
      extend T::Sig

      private

      sig do
        params(data: String).
        returns([
          T.nilable(ParseError),
          # Data
          String,
          # Bytes consumed
          Integer,
        ])
      end
      def scan_and_parse_json_string_or_literal(data)
        if data[0] == '"'
          err, consumed, nbytes_consumed = scan_json_string(data)
          if err
            [err, "", 0]
          else
            [nil, JSON.parse(consumed), nbytes_consumed]
          end
        else
          scan_literal(data)
        end
      end

      sig do
        params(data: String).
        returns([
          T.nilable(ParseError),
          # Data
          String,
          # Bytes consumed
          Integer
        ])
      end
      def scan_json_string(data)
        scanner = StringScanner.new(data)
        return [ParseError.new("Invalid JSON string encountered: missing opening quote"), "", 0] if scanner.skip('"').nil?

        consumed = String.new(encoding: Encoding::UTF_8, capacity: data.size)
        consumed << '"'
        while true
          locally_consumed = scanner.scan_until(/[\\"]/)

          case locally_consumed[-1]
          when '"'
            # Closing quote encountered
            consumed << locally_consumed[0 .. -1]
            return [nil, consumed, scanner.pos]
          when "\\"
            # Consume escape sequence
            consumed << locally_consumed[0 .. -1]
            return [ParseError.new("Invalid escape sequence encountered in JSON string"), "", 0] if scanner.eos?
            consumed << scanner.getch
            return [ParseError.new("Invalid JSON string encountered: missing closing quote"), "", 0] if scanner.eos?
          when nil
            return [ParseError.new("Invalid JSON string encountered: missing closing quote"), "", 0]
          else
            Kernel.raise "BUG: impossible branch"
          end
        end
      end

      sig do
        params(data: String).
        returns([
          T.nilable(ParseError),
          # Data
          String,
          # Bytes consumed
          Integer
        ])
      end
      def scan_literal(data)
        scanner = StringScanner.new(data)
        consumed = scanner.scan_until(/(:?=|\s|\Z)/)
        if consumed[-1] =~ /[=\s]/
          [nil, T.must(consumed[0 .. -2]), scanner.pos - 1]
        else
          [nil, T.must(consumed[0 .. -1]), scanner.pos]
        end
      end

      sig do
        params(data: String).
        returns([
          T.nilable(ParseError),
          # Data
          String,
          # Bytes consumed
          Integer
        ])
      end
      def scan_json(data)
        if data[0] == "["
          scan_json_array(data)
        elsif data[0] == "{"
          scan_json_object(data)
        else
          scan_json_primitive(data)
        end
      end

      sig do
        params(data: String).
        returns([
          T.nilable(ParseError),
          # Data
          String,
          # Bytes consumed
          Integer
        ])
      end
      def scan_json_array(data)
        scanner = StringScanner.new(data)
        return [ParseError.new("Invalid JSON array encountered: no opening bracket"), "", 0] if !scanner.skip("[")
        scanner.skip(/\s+/)

        while true
          if scanner.skip("]")
            return [nil, T.must(data[0 .. scanner.pos - 1]), scanner.pos]
          elsif scanner.eos?
            return [ParseError.new("Invalid JSON array encountered: no closing bracket"), "", 0]
          end

          err, _elem, consumed_size = scan_json(scanner.rest)
          return [err, "", 0] if err
          scanner.pos += consumed_size
          scanner.skip(/\s+/)
          scanner.skip(",")
          scanner.skip(/\s+/)
        end
      end

      sig do
        params(data: String).
        returns([
          T.nilable(ParseError),
          # Data
          String,
          # Bytes consumed
          Integer
        ])
      end
      def scan_json_object(data)
        scanner = StringScanner.new(data)
        return [ParseError.new("Invalid JSON object encountered: no opening brace"), "", 0] if !scanner.skip("{")
        scanner.skip(/\s+/)

        while true
          if scanner.skip("}")
            return [nil, T.must(data[0 .. scanner.pos - 1]), scanner.pos]
          elsif scanner.eos?
            return [ParseError.new("Invalid JSON object encountered: no opening brace"), "", 0]
          end

          err, key, key_size = scan_json_string(scanner.rest)
          return [err, "", 0] if err
          scanner.pos += key_size

          scanner.skip(/\s+/)
          return [ParseError.new("Invalid JSON object encountered: no delimiter after key #{key.inspect}"), "", 0] if !scanner.skip(":")
          scanner.skip(/\s+/)

          err, _value, value_size = scan_json(scanner.rest)
          return [err, "", 0] if err
          scanner.pos += value_size

          scanner.skip(/\s+/)
          scanner.skip(",")
          scanner.skip(/\s+/)
        end
      end

      sig do
        params(data: String).
        returns([
          T.nilable(ParseError),
          # Data
          String,
          # Bytes consumed
          Integer
        ])
      end
      def scan_json_primitive(data)
        scanner = StringScanner.new(data)
        if (consumed = scanner.scan(/([0-9\.]+|true|false|null)/))
          [nil, consumed, scanner.pos]
        elsif scanner.match?('"')
          scan_json_string(data)
        else
          [ParseError.new("Invalid JSON primitive encountered"), "", 0]
        end
      end

      sig do
        params(data: String, offset: Integer).
        returns([
          T.nilable(ParseError),
          # Properties
          T::Hash[String, T.untyped],
          # Bytes consumed
          Integer,
        ])
      end
      def scan_and_parse_kv_params(data, offset = 0)
        pos = 0
        properties = {}

        while pos < data.size
          # Scan key
          err, key, key_size = scan_and_parse_json_string_or_literal(T.must(data[pos .. -1]))
          return [ParseError.new("Failed to parse key at position #{offset + pos}: #{err.message}"), {}, 0] if err
          if key.empty?
            debug "Failed to scan key at position #{offset + pos}"
            return [nil, {}, 0]
          end
          pos += key_size

          # Scan delimiter
          if data[pos] != '='
            debug "Failed to scan delimiter at position #{offset + pos}"
            return [nil, {}, 0]
          end
          pos += 1

          # Scan value
          if data[pos] == ' ' || data[pos].nil?
            value = ""
          else
            # Value may be a serialized JSON document. Try parsing it, but it's
            # fine if that fails.
            err, value, value_size = scan_json(T.must(data[pos .. -1]))
            if err
              err, value, value_size = scan_literal(T.must(data[pos .. -1]))
              return [ParseError.new("Failed to scan value at position #{offset + pos}: #{err.message}"), {}, 0] if err
            else
              value = JSON.parse(value)
              if value.is_a?(String)
                begin
                  value = JSON.parse(value)
                rescue JSON::ParserError
                end
              end
            end
            pos += value_size
          end

          properties[key] = value
          # Skip spaces
          pos += 1 while data[pos] == ' '
        end

        [nil, properties, pos]
      end

      if ENV['DEBUG'] == '1'
        def debug(message)
          STDERR.puts "!!! #{message}"
        end
      else
        def debug(_message); end
      end
    end
  end
end
