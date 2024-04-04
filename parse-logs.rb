#!/usr/bin/env ruby
# typed: true
# frozen_string_literal: true

require 'bundler/setup'
require_relative 'lib/app'

LogsParser::App.new.run
