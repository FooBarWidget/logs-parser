# typed: true
# frozen_string_literal: true

require 'sorbet-runtime'
require_relative 'parser/go_log'
require_relative 'parser/generic_json'
# require_relative 'output/pretty'
# require_relative 'output/json'
require_relative 'output/csv'

module LogsParser
  class App
    extend T::Sig

    PARSERS = T.let([
      Parser::GoLog.new,
      Parser::GenericJson.new
    ], T::Array[Parser::Base])

    def initialize
      # @output = Output::Pretty.new
      # @output = Output::JSON.new
      @output = Output::CSV.new(ARGV[1] || 'output.csv')
    end

    def run
      input.each_line do |line|
        line.chomp!
        next if line.empty?

        message = parse(line)
        if message.nil?
          puts line
        else
          @output.write(message)
        end
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

    sig { params(line: String).returns(T.nilable(StructuredMessage)) }
    def parse(line)
      PARSERS.each do |parser|
        message = parser.parse(line)
        return message if message
      end
      nil
    end
  end
end
