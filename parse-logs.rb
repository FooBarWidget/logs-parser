#!/usr/bin/env ruby
require 'strscan'
require 'json'

MESSAGE_KEY = "message"

LEVEL_KEY = "level"
LEVEL_ERROR = "error"
LEVEL_WARN = "warn"
LEVEL_INFO = "info"
LEVEL_DEBUG = "debug"

ANSI_COLOR_RED = "\033[31m"
ANSI_COLOR_YELLOW = "\033[33m"
ANSI_COLOR_GRAY = "\033[37m"
ANSI_COLOR_RESET = "\033[0m"

class GoLogParser
  def parse(line)
    return if line !~ /^([A-Z])([0-9]+) ([0-9][0-9]:[0-9][0-9]:[0-9][0-9]\.[0-9]+)       [0-9]+ (\S+\.go):([0-9]+)\] (.+)/
    level = $1
    code = $2
    time = $3
    filename = $4
    line_number = $5
    result = {
      LEVEL_KEY => parse_level(level),
      "code" => code,
      "time" => time,
      "filename" => filename,
      "line_number" => $5.to_i,
    }
    payload = $6
    if parsed_payload = parse_payload(payload)
      result.merge!(parsed_payload)
      result
    else
      result.merge!(MESSAGE_KEY => payload)
    end
  end

  private

  def parse_level(level)
    case level
    when "E"
      LEVEL_ERROR
    when "W"
      LEVEL_WARN
    when "I"
      LEVEL_INFO
    when "D"
      LEVEL_DEBUG
    else
      level
    end
  end

  # Input string: "Event occurred" object="container-registry-enforce" kind="ClusterPolicy"
  # Output: { message: "Event occurred", object: "container-registry-enforce", kind: "ClusterPolicy" }
  def parse_payload(payload)
    pos = 0

    # Scan optional component identifier
    if payload[pos] != "\""
      component, component_size = scan_literal(payload)
      if component
        pos += component_size

        # Skip spaces
        pos += 1 while payload[pos] == ' '
      end
    end

    # Scan optional main message
    main_message, main_message_size = scan_c_string_or_literal(payload[pos .. -1])
    if main_message
      if payload[pos + main_message_size] == "="
        # This is not actually a main message but a key-value pair. Unscan this.
        main_message = nil
      else
        pos += main_message_size
      end
    end

    # Scan key-value pairs
    result = {}
    while pos < payload.size
      # Skip spaces
      pos += 1 while payload[pos] == ' '
      break if pos >= payload.size

      # Scan key
      key, key_size = scan_c_string_or_literal(payload[pos .. -1])
      if key.nil? || pos >= payload.size
        debug "Failed to scan key at position #{pos} in payload"
        return nil
      end
      pos += key_size

      # Scan delimiter
      if payload[pos] != '='
        debug "Failed to scan delimiter at position #{pos} in payload"
        return nil
      end
      pos += 1

      # Scan value
      value, value_size = scan_c_string_or_literal(payload[pos .. -1])
      if value.nil? || pos >= payload.size
        debug "Failed to scan value at position #{pos} in payload"
        return nil
      end
      pos += value_size

      result[key] = value
    end

    result["component"] = component if component
    if main_message
      result[MESSAGE_KEY] = main_message
    elsif result.key?("msg")
      result[MESSAGE_KEY] = result.delete("msg")
    end
    result
  end

  def scan_c_string_or_literal(data)
    scanner = StringScanner.new(data)
    return scan_literal(data) if !scanner.scan(/\"/)

    done = false
    result = String.new(encoding: 'UTF-8', capacity: data.size)
    while !done
      consumed = scanner.scan_until(/[\\"]/)

      last_char = consumed[-1]
      case last_char
      when '"'
        result << consumed[0 .. -2]
        done = true
      when "\\"
        result << consumed[0 .. -2]
        result << unescape_char(scanner.getch)
        done = scanner.eos?
      else
        result << consumed
        done = scanner.eos?
      end
    end

    [result, scanner.pos]
  end

  def scan_literal(data)
    scanner = StringScanner.new(data)
    consumed = scanner.scan_until(/(:?=|\s|\Z)/)
    if consumed.nil?
      nil
    elsif scanner.eos?
      [consumed, scanner.pos]
    else
      [consumed[0 .. -2], scanner.pos - 1]
    end
  end

  def unescape_char(char)
    case char
    when "n"
      "\n"
    when "t"
      "\t"
    else
      char
    end
  end

  def debug(message)
    puts "!!! #{message}"
  end
end

class GenericJsonParser
  def parse(line)
    JSON.parse(line)
  rescue JSON::ParserError
    nil
  end
end

class App
  PARSERS = [GoLogParser.new, GenericJsonParser.new]

  def run
    input.each_line do |line|
      line.chomp!
      next if line.empty?

      message = parse(line)
      if message.nil?
        puts line
      else
        pretty_print_message(message)
      end
    end
  end

  private

  def input
    if ARGV[0]
      File.open(ARGV[0], "r:utf-8")
    else
      STDIN
    end
  end

  def parse(line)
    PARSERS.each do |parser|
      message = parser.parse(line)
      return message if message
    end
    nil
  end

  def pretty_print_message(message)
    props = message.dup
    props.delete(MESSAGE_KEY)
    max_key_size = props.keys.max_by(&:size).size
    level = props.delete(LEVEL_KEY)

    display = message[MESSAGE_KEY]
    if display && !display.empty?
      puts colorize(display, color_for_level(level))
    else
      puts colorize("(No message)", color_for_level(level))
    end

    if level
      printf "    %-#{max_key_size}s: %s\n", LEVEL_KEY, colorize(level, color_for_level(level))
    end
    props.each_pair do |key, value|
      printf "    %-#{max_key_size}s: %s\n", key, value
    end
  end

  def color_for_level(level)
    case level
    when LEVEL_ERROR
      ANSI_COLOR_RED
    when LEVEL_WARN
      ANSI_COLOR_YELLOW
    when LEVEL_DEBUG
      ANSI_COLOR_GRAY
    else
      nil
    end
  end

  def colorize(text, color)
    if color
      "#{color}#{text}#{ANSI_COLOR_RESET}"
    else
      text
    end
  end
end

App.new.run
