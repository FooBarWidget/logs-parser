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

        done = T.let(false, T::Boolean)
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
    end
  end
end
