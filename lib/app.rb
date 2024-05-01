# typed: true
# frozen_string_literal: true

require 'sorbet-runtime'
require_relative 'parser/go_klog_text'
require_relative 'parser/go_klog_params'
require_relative 'parser/generic_json'
require_relative 'post_processor/display_message'
require_relative 'post_processor/timestamp'
require_relative 'output/pretty'
# require_relative 'output/json'
require_relative 'output/csv'

module LogsParser
  class App
    extend T::Sig

    PARSE_PIPELINE = T.let([
      Parser::GoKlogText.new,
      Parser::GoKlogParams.new,
      Parser::GenericJson.new,
    ], T::Array[Parser::Base])

    POST_PROCESSING_PIPELINE = T.let([
      PostProcessor::DisplayMessage.new,
      PostProcessor::Timestamp.new,
    ], T::Array[PostProcessor::Base])

    def initialize
      @output = Output::Pretty.new
      # @output = Output::JSON.new
      # @output = Output::CSV.new(ARGV[1] || 'output.csv')
    end

    def run
      input.each_line do |line|
        line.chomp!
        next if line.empty?
        @output.write(postprocess(parse(line)))
      end
    ensure
      @output.close
    end

    private

    def input
      if ARGV[0]
        File.open(ARGV[0], "r:utf-8")
      else
        STDIN
      end
    end

    sig { params(line: String).returns(StructuredMessage) }
    def parse(line)
      message = StructuredMessage.new(display_message: line, raw: line)

      PARSE_PIPELINE.each do |parser|
        message = try_parse_with_parser_and_merge(parser, message, T.must(message.unparsed_raw || message.display_message))
        break if message.unparsed_raw.nil? && message.display_message.nil?
      end

      if message.display_message.nil? && message.unparsed_raw
        message.display_message = message.unparsed_raw
        message.unparsed_raw = nil
      end

      message
    end

    sig { params(parser: Parser::Base, old_message: StructuredMessage, raw: String).returns(StructuredMessage) }
    def try_parse_with_parser_and_merge(parser, old_message, raw)
      err, new_message = parser.parse(raw)
      if err
        STDERR.puts "Parse error: #{err.message}"
        old_message
      elsif new_message
        old_message.merge(new_message)
      else
        old_message
      end
    end

    sig { params(message: StructuredMessage).returns(StructuredMessage) }
    def postprocess(message)
      POST_PROCESSING_PIPELINE.each do |processor|
        message = processor.process(message) || message
      end
      message
    end
  end
end
