# frozen_string_literal: true

require 'configatron'
require 'getoptlong'
require 'yaml'
require 'dotenv/load'


DEFAULT_CONFIG_FILE = 'config/app.example.yml'
CONFIG_FILE = 'config/app.yml'

Config = configatron
Config.root = File.absolute_path(File.expand_path('..', __dir__))

configs_hash = YAML.load_file(File.join(Config.root, DEFAULT_CONFIG_FILE))
if File.exist?(File.join(Config.root, CONFIG_FILE))
  configs_hash.merge!(YAML.load_file(File.join(Config.root, CONFIG_FILE)))
end

Config.configure_from_hash(configs_hash)

Config.google_places_api_key = ENV['GOOGLE_PLACES_API_KEY'] if ENV['GOOGLE_PLACES_API_KEY'].present?

FARADAY_RETRY_OPTIONS = {
  max: 2,
  interval: 0.05,
  interval_randomness: 0.5,
  backoff_factor: 2
}


# #######################
# Options management
# #######################
opts = GetoptLong.new(
  ['--debug',            GetoptLong::NO_ARGUMENT],
  ['--help',       '-h', GetoptLong::NO_ARGUMENT],
  ['--file',            GetoptLong::REQUIRED_ARGUMENT],
  ["--query-key",       GetoptLong::REQUIRED_ARGUMENT],
  ["--output-file",     GetoptLong::REQUIRED_ARGUMENT],
)

USAGE_OPTIONS = [
  {
    option: '--debug',
    desc:
    <<~DOC.strip.split("\n")
      Avvia lo scrapping in modalità debug.

      Usage:
      ruby #{$PROGRAM_NAME} -v
    DOC
  },
  {
    option: '-h, --help',
    desc:
    <<~DOC.strip.split("\n")
      Visualizza questo messaggio di aiuto.

      ruby #{$PROGRAM_NAME} -h
    DOC
  },
  {
    option: '--file',
    desc:
    <<~DOC.strip.split("\n")
      File location

      Usage:
      ruby #{$PROGRAM_NAME} <command> --file /path/to/file

      Example:
      ruby run.rb import-query --file spec/fixtures/query-frantoi-italia.txt
    DOC
  },
  {
    option: '--query-key, --query-keys',
    desc:
    <<~DOC.strip.split("\n")
      Query key to use for import of queries or export of places.

      Usage:
      ruby #{$PROGRAM_NAME} <command> --query-key <key>

      Example:
      ruby run.rb import-query --file spec/fixtures/query-frantoi-italia.txt --query-key=mario
    DOC
  },
  {
    option: "--output-file",
    desc: 
    <<~DOC.strip.split("\n")
      Specify output file for export.

      Usage:
      ruby #{$PROGRAM_NAME} <command> --output-file /path/to/output/file

      Example:
      ruby run.rb export --output-file mario.csv
    DOC
  }
]

# Setting defaults.
USAGE_OPTIONS.each do |option|
  option[:option].split(',').each do |opt|
    Config[opt.strip.delete_prefix('--').delete_prefix('-').tr('-', '_').to_sym] = nil
  end
end

USAGE_MESSAGE = <<~DOC
  Usage:

  ruby #{$PROGRAM_NAME} <command> [options]

  Commands:
  - import-queries: Import queries from file. Specify file with --file and --query-key options.
  - finder: Start Finder worker. Will process queries and create blank places.
  - processor: Start Processor worker. Will process places and update them with data.
  - console: Start interactive console
  - watcher: Will fix any broken records and log status.

DOC

def print_help_message
  puts USAGE_MESSAGE
  puts "OPTIONS:\n"
  USAGE_OPTIONS.each do |option|
    puts "\t#{option[:option]}"
    puts "\t\t#{option[:desc].join("\n\t\t")}\n\n"
  end
end

opts.each do |opt, arg|
  case opt
  when '--debug'
    Config.debug = true
    puts 'Enabled debug mode'
  when '--file'
    Config.file = arg
  when '--help'
    print_help_message
    exit
  when '--query-key', '--query-keys'
    Config.query_key = arg
  when '--output-file', '--outfile', '-o'
    Config.output_file = arg
  end
end

# #######################
# Validating configurations
# #######################
raise 'Missing Google Places API Key' if Config.google_places_api_key.nil?