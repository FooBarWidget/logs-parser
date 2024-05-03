# typed: true
# frozen_string_literal: true

require 'sorbet-runtime'
require_relative 'parser/go_klog_prefix'
require_relative 'parser/go_klog_params'
require_relative 'parser/generic_json'
require_relative 'post_processor/timestamp'
require_relative 'post_processor/level'
require_relative 'post_processor/display_message'
require_relative 'output/pretty'
require_relative 'output/json'
require_relative 'output/csv'

module LogsParser
  class App
    extend T::Sig

    PARSE_PIPELINE = T.let([
      Parser::GoKlogPrefix.new,
      Parser::GoKlogParams.new,
      Parser::GenericJson.new,
    ], T::Array[Parser::Base])

    POST_PROCESSING_PIPELINE = T.let([
      PostProcessor::Timestamp.new,
      PostProcessor::Level.new,
      PostProcessor::DisplayMessage.new,
    ], T::Array[PostProcessor::Base])

    def initialize
      # @output = Output::Pretty.new
      # @output = Output::JSON.new
      @output = Output::CSV.new(ARGV[1] || 'output.csv')
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
      if ARGV[0] && ARGV[0] != "-"
        File.open(ARGV[0], "r:utf-8")
      else
        STDIN
      end
    end

    sig { params(raw: String).returns(StructuredMessage) }
    def parse(raw)
      message = StructuredMessage.new(unparsed_remainder: raw, raw: raw, properties: {})

      PARSE_PIPELINE.each do |parser|
        accepted, err = parser.parse(message)
        if err
          STDERR.puts "Parse error: #{err.message}"
        end
      end

      if message.display_message.nil? && !message.unparsed_remainder.empty?
        message.display_message = message.unparsed_remainder
        message.unparsed_remainder = ""
      end

      message
    end

    sig { params(message: StructuredMessage).returns(StructuredMessage) }
    def postprocess(message)
      POST_PROCESSING_PIPELINE.each do |processor|
        processor.process(message)
      end
      message
    end
  end
end
