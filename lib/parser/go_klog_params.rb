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
    # Parses the parameters (key-values) part of a klog message. Something like:
    #
    #   count=2 object="container-registry-enforce" kind="ClusterPolicy" target={"name":"foo"}
    #
    # https://kubernetes.io/docs/concepts/cluster-administration/system-logs/
    # https://github.com/kubernetes/klog/tree/main/textlogger
    class GoKlogParams < Base
      sig do
        override.
        params(raw: String, offset: Integer).
        returns([
          T.nilable(ParseError),
          T.nilable(StructuredMessage),
        ])
      end
      def parse(raw, offset = 0)
        properties = {}
        pos = 0

        while pos < raw.size
          # Scan key
          err, key, key_size = scan_and_parse_json_string_or_literal(T.must(raw[pos .. -1]))
          return [ParseError.new("Failed to parse key at position #{offset + pos}: #{err.message}"), nil] if err
          if key.empty?
            debug "Failed to scan key at position #{offset + pos}"
            return [nil, nil]
          end
          pos += key_size

          # Scan delimiter
          if raw[pos] != '='
            debug "Failed to scan delimiter at position #{offset + pos}"
            return [nil, nil]
          end
          pos += 1

          # Scan value
          if raw[pos] == ' ' || raw[pos].nil?
            value = ""
          else
            # Value may be a serialized JSON document. Try parsing it, but it's
            # fine if that fails.
            err, value, value_size = scan_json(T.must(raw[pos .. -1]))
            if err
              err, value, value_size = scan_literal(T.must(raw[pos .. -1]))
              return [ParseError.new("Failed to scan value at position #{offset + pos}: #{err.message}"), nil] if err
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
          pos += 1 while raw[pos] == ' '
        end

        [nil, StructuredMessage.new(properties: properties, raw: raw)]
      end

      private

      include GoKlogHelper

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

          err, elem, consumed_size = scan_json(scanner.rest)
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

          err, value, value_size = scan_json(scanner.rest)
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
