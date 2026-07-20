#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler'
Bundler.require

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
else
  puts "Invalid command: #{ARGV[0].inspect}"
  print_help_message
  exit 1
end
