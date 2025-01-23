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
    # Parses the parameters (key-values) part of a klog-like message. Something like:
    #
    #   count=2 object="container-registry-enforce" kind="ClusterPolicy" target={"name":"foo"}
    #
    # More info about klog:
    # https://kubernetes.io/docs/concepts/cluster-administration/system-logs/
    # https://github.com/kubernetes/klog/tree/main/textlogger
    class GoKlogParams < Base
      sig do
        override.
        params(message: StructuredMessage, offset: Integer).
        returns([
          T::Boolean,
          T.nilable(ParseError),
        ])
      end
      def parse(message, offset = 0)
        err, properties, ncharsconsumed = scan_and_parse_kv_params(message.unparsed_remainder, offset, support_unquoted_sentences: true)
        if err
          [true, err]
        elsif ncharsconsumed > 0
          message.unparsed_remainder = T.must(message.unparsed_remainder[offset + ncharsconsumed .. -1])
          message.properties.merge!(properties)
          [true, nil]
        else
          [false, nil]
        end
      end

      private

      include GoKlogHelper
    end
  end
end
