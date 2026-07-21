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
  check_config_validity
when "config-edit", "ce"
  edit_config_file
when "config-show", "cs"
  show_current_config
when "run", "start"
  create_configuration_file_if_not_exists
  check_config_validity
  # TODO: Implementare la logica per eseguire i controlli e salvare i risultati.
  # start checks and save results in logfiles and print to console
when "stop", "halt"
  puts "TODO: Stop the running checks."
# when 'finder'
#   # require_relative 'app/interactions/finder'
#   Finder.run!
# when "import-query", "import-queries"
#   ImportQueries.run!
# when "processor"
#   Processor.run!
# when "export"
#   Exporter.run!
# when "watcher", "monitor"
#   Watcher.run!
  RunAllChecks.run!
when "stop", "halt", "cancel"
  CancelRunningChecks.run!
else
  puts "Invalid command: #{ARGV[0].inspect}"
  print_help_message
  exit 1
end
