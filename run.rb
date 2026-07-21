#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler'
Bundler.require

require_relative 'app/version'
require_relative 'app/config'
require_relative 'app/logger'
require_relative 'app/database'
require_relative 'app/helpers'

load_paths = ['app/models/', 'app/utilities', "app/interactions"]

load_paths.each do |path|
  next unless File.exist?(path)

  require_recursive(File.join(Config.root, path), '*.rb')
end

case ARGV[0]
when 'console', "c"
  require 'pry'
  Pry.start
when "version"
  puts "Version: #{VERSION}"
when "help", "-h"
  print_help_message
when "config-check", "cc"
  puts "TODO: Read configs and check if they are valid."
when "config-edit", "ce"
  puts "TODO: Open config file in editor."
when "config-show", "cs"
  puts "TODO: Show current configuration."
when "run", "start"
  RunAllChecks.run!
when "stop", "halt", "cancel"
  CancelRunningChecks.run!
else
  puts "Invalid command: #{ARGV[0].inspect}"
  print_help_message
  exit 1
end
