# typed: true
# frozen_string_literal: true

require 'sorbet-runtime'
require 'set'
require 'json'
require 'csv'
require_relative 'base'

module LogsParser
  module Output
    class CSV < Base
      STANDARD_HEADERS = ['@timestamp', '@time', '@level', '@message'].freeze

      sig { params(path: String, header_properties: T::Array[String]).void }
      def initialize(path, header_properties: [])
        @path = path
        @header_properties = T.let(Set.new(STANDARD_HEADERS + header_properties), T::Set[String])
        @serialized_messages = T.let([], T::Array[T::Hash[String, T.untyped]])
        @headers_index = T.let({}, T::Hash[String, Integer])
      end

      sig { override.params(message: StructuredMessage).void }
      def write(message)
        sm = serialize_to_hash(message)
        index_headers(sm.keys)
        @serialized_messages << sm
      end

      def close
        csv = ::CSV.open(@path, "wb", encoding: Encoding::UTF_8)
        begin
          csv << @headers_index.keys
          @serialized_messages.each do |sm|
            csv << serialize_to_array(sm)
          end
        ensure
          csv.close
        end
      end

      private

      sig { params(message: StructuredMessage).returns(T::Hash[String, T.untyped]) }
      def serialize_to_hash(message)
        result = {}
        if message.timestamp
          result['@timestamp'] = message.timestamp&.iso8601
        elsif message.time
          result['@time'] = message.time
        end
        result['@level'] = message.level if message.level
        result['@message'] = message.display_message if message.display_message
        result.merge!(T.must(message.properties)) if message.properties
        result
      end

      sig { params(serialized_message: T::Hash[String, T.untyped]).returns(T::Array[T.untyped]) }
      def serialize_to_array(serialized_message)
        result = []
        @headers_index.each_pair do |header, index|
          value = serialized_message[header]
          if value.is_a?(Array) || value.is_a?(Hash)
            value = ::JSON.generate(value)
          end
          result[index] = value
        end
        result
      end

      sig { params(headers: T::Array[String]).void }
      def index_headers(headers)
        headers.each do |header|
          @headers_index[header] ||= @headers_index.size
        end
      end
    end
  end
end
