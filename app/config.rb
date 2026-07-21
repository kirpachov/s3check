# frozen_string_literal: true

require 'configatron'
require 'dotenv/load'
require 'yaml'

DEFAULT_CONFIG_FILE = 'config/app.example.yml'
CONFIG_FILE = 'config/app.yml'

Config = configatron
Config.root = File.absolute_path(File.expand_path('..', __dir__))
Config.pid_file_path = "tmp/run.pid"

def deep_merge_hash(base_hash, override_hash)
  base_hash.merge(override_hash) do |_key, base_value, override_value|
    if base_value.is_a?(Hash) && override_value.is_a?(Hash)
      deep_merge_hash(base_value, override_value)
    else
      override_value
    end
  end
end

def load_config!
  default_file_path = File.join(Config.root, DEFAULT_CONFIG_FILE)
  raise "File di default mancante: #{DEFAULT_CONFIG_FILE}" unless File.exist?(default_file_path)

  merged_config = YAML.load_file(default_file_path) || {}

  custom_file_path = File.join(Config.root, CONFIG_FILE)
  if File.exist?(custom_file_path)
    custom_config = YAML.load_file(custom_file_path) || {}
    merged_config = deep_merge_hash(merged_config, custom_config)
  end

  Config.configure_from_hash(merged_config)
end

# #######################
# Options management
# #######################
opts = GetoptLong.new(
  ['--debug',            GetoptLong::NO_ARGUMENT],
  ['--help',       '-h', GetoptLong::NO_ARGUMENT],
  # ['--file',            GetoptLong::REQUIRED_ARGUMENT],
  # ["--query-key",       GetoptLong::REQUIRED_ARGUMENT],
  # ["--output-file",     GetoptLong::REQUIRED_ARGUMENT],
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
  # {
  #   option: '--file',
  #   desc:
  #   <<~DOC.strip.split("\n")
  #     File location

  #     Usage:
  #     ruby #{$PROGRAM_NAME} <command> --file /path/to/file

  #     Example:
  #     ruby run.rb import-query --file spec/fixtures/query-frantoi-italia.txt
  #   DOC
  # },
  # {
  #   option: '--query-key, --query-keys',
  #   desc:
  #   <<~DOC.strip.split("\n")
  #     Query key to use for import of queries or export of places.

  #     Usage:
  #     ruby #{$PROGRAM_NAME} <command> --query-key <key>

  #     Example:
  #     ruby run.rb import-query --file spec/fixtures/query-frantoi-italia.txt --query-key=mario
  #   DOC
  # },
  # {
  #   option: "--output-file",
  #   desc:
  #   <<~DOC.strip.split("\n")
  #     Specify output file for export.

  #     Usage:
  #     ruby #{$PROGRAM_NAME} <command> --output-file /path/to/output/file

  #     Example:
  #     ruby run.rb export --output-file mario.csv
  #   DOC
  # }
]

# Setting defaults.
USAGE_OPTIONS.each do |option|
  option[:option].split(',').each do |opt|
    Config[opt.strip.delete_prefix('--').delete_prefix('-').tr('-', '_').to_sym] = nil
  end
end

def config_file_exists?
  File.exist?(File.join(Config.root, CONFIG_FILE))
end

def create_configuration_file_if_not_exists
  return if config_file_exists?

  puts "Configurazione non trovata (#{CONFIG_FILE})."
  puts 'Avvio installazione guidata per Amazon S3...'

  print 'S3 region (es. eu-west-1): '
  region = STDIN.gets&.chomp.to_s

  print 'S3 bucket: '
  bucket = STDIN.gets&.chomp.to_s

  print 'S3 endpoint (opzionale, invio per default AWS): '
  endpoint = STDIN.gets&.chomp.to_s

  print 'S3 prefix backup (opzionale, es. backups/daily): '
  backup_prefix = STDIN.gets&.chomp.to_s

  config_to_write = {
    's3' => {
      'region' => region,
      'bucket' => bucket,
      'endpoint' => endpoint,
      'backup_prefix' => backup_prefix
    }
  }

  File.open(File.join(Config.root, CONFIG_FILE), 'w') do |file|
    file.write(config_to_write.to_yaml)
  end

  load_config!
  puts "Installazione completata: creato #{CONFIG_FILE}."
end

def check_config_validity
  s3 = Config.s3
  s3_access_key_id = ENV['S3_ACCESS_KEY_ID'].to_s.strip
  s3_secret_access_key = ENV['S3_SECRET_ACCESS_KEY'].to_s.strip

  missing_keys = []
  missing_keys << 'ENV.S3_ACCESS_KEY_ID' if s3_access_key_id.empty?
  missing_keys << 'ENV.S3_SECRET_ACCESS_KEY' if s3_secret_access_key.empty?
  missing_keys << 's3.region' if s3&.region.to_s.strip.empty?
  missing_keys << 's3.bucket' if s3&.bucket.to_s.strip.empty?

  if missing_keys.any?
    puts "Configurazione non valida. Campi mancanti: #{missing_keys.join(', ')}"
    exit 1
  end

  puts 'Configurazione S3 valida.'
end

def edit_config_file
  create_configuration_file_if_not_exists

  editor = ENV['EDITOR'].to_s.strip
  editor = 'nano' if editor.empty?

  system(editor, File.join(Config.root, CONFIG_FILE))
end

def show_current_config
  s3 = Config.s3
  has_access_key_id = !ENV['S3_ACCESS_KEY_ID'].to_s.strip.empty?
  has_secret_access_key = !ENV['S3_SECRET_ACCESS_KEY'].to_s.strip.empty?

  puts 'Configurazione in uso:'
  puts "- file default: #{DEFAULT_CONFIG_FILE}"
  puts "- file custom:  #{CONFIG_FILE}#{config_file_exists? ? '' : ' (non presente)'}"
  puts '- env (.env):'
  puts "    S3_ACCESS_KEY_ID: #{has_access_key_id ? 'presente' : 'mancante'}"
  puts "    S3_SECRET_ACCESS_KEY: #{has_secret_access_key ? 'presente' : 'mancante'}"
  puts '- s3:'
  puts "    region: #{s3&.region}"
  puts "    bucket: #{s3&.bucket}"
  puts "    endpoint: #{s3&.endpoint}"
  puts "    backup_prefix: #{s3&.backup_prefix}"
end

USAGE_MESSAGE = <<~DOC
  Usage:

  ruby #{$PROGRAM_NAME} <command>

  Commands:
     run               Start all checks. Will read configs and run all the checks.
     stop              Stop running checks. Will send TERM signal to the running process.
     config-check      Check the validity of the configuration. Will check if all required configs are present.
     config-edit       Edit the configuration file. Will open the config file in the default editor.
     config-show       Show the current configuration. Will display the current configuration values.
     version           Show the current version of the application.
     console           Start an interactive console for debugging and testing.

DOC

def print_help_message
  puts USAGE_MESSAGE
end

load_config!
# opts.each do |opt, arg|
#   case opt
#   when '--debug'
#     Config.debug = true
#     puts 'Enabled debug mode'
#   when '--file'
#     Config.file = arg
#   when '--help'
#     print_help_message
#     exit
#   when '--query-key', '--query-keys'
#     Config.query_key = arg
#   when '--output-file', '--outfile', '-o'
#     Config.output_file = arg
#   end
# end

# # #######################
# # Validating configurations
# # #######################
# raise 'Missing Google Places API Key' if Config.google_places_api_key.nil?
