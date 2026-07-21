# frozen_string_literal: true

require 'configatron'
require 'dotenv/load'
require 'yaml'

DEFAULT_CONFIG_FILE = 'config/app.example.yml'
CONFIG_FILE = 'config/app.yml'
DEFAULT_CHECKS_FILE = 'config/checks.example.yml'
CHECKS_FILE = 'config/checks.yml'
ENV_FILE = '.env'
DEFAULT_ENV_FILE = '.env.example'

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
  raise "Missing default config file: #{DEFAULT_CONFIG_FILE}" unless File.exist?(default_file_path)

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
      Start scraping in debug mode.

      Usage:
      ruby #{$PROGRAM_NAME} -v
    DOC
  },
  {
    option: '-h, --help',
    desc:
    <<~DOC.strip.split("\n")
      Show this help message.

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

def checks_file_path
  File.join(Config.root, CHECKS_FILE)
end

def default_checks_file_path
  File.join(Config.root, DEFAULT_CHECKS_FILE)
end

def checks_file_exists?
  File.exist?(checks_file_path)
end

def env_file_path
  File.join(Config.root, ENV_FILE)
end

def default_env_file_path
  File.join(Config.root, DEFAULT_ENV_FILE)
end

def env_file_exists?
  File.exist?(env_file_path)
end

def editor_command
  editor = ENV['EDITOR'].to_s.strip
  editor.empty? ? 'nano' : editor
end

def ensure_env_file_exists
  return if env_file_exists?

  if File.exist?(default_env_file_path)
    File.write(env_file_path, File.read(default_env_file_path))
    return
  end

  File.open(env_file_path, 'w') do |file|
    file.write("# Amazon S3 credentials\n")
    file.write("S3_ACCESS_KEY=\n")
    file.write("S3_SECRET_KEY=\n")
  end
end

def open_env_file_in_editor
  ensure_env_file_exists
  system(editor_command, env_file_path)
  reload_env!
end

def ensure_checks_file_exists
  return if checks_file_exists?

  if File.exist?(default_checks_file_path)
    File.write(checks_file_path, File.read(default_checks_file_path))
    return
  end

  File.open(checks_file_path, 'w') do |file|
    file.write({
      'checks' => [
        {
          'name' => 'Example check',
          'bucket' => '',
          'check' => [
            {
              'type' => 'folder_not_empty',
              'params' => {
                'folder_path' => ''
              }
            }
          ]
        }
      ]
    }.to_yaml)
  end
end

def open_checks_file_in_editor
  ensure_checks_file_exists
  system(editor_command, checks_file_path)
end

def reload_env!
  Dotenv.overload(env_file_path) if File.exist?(env_file_path)
end

def create_configuration_file_if_not_exists
  return if config_file_exists?

  puts "Configuration not found (#{CONFIG_FILE})."
  puts 'Starting guided setup for Amazon S3...'

  print 'S3 region (e.g. eu-west-1): '
  region = STDIN.gets&.chomp.to_s

  config_to_write = {
    's3' => {
      'region' => region
    }
  }

  File.open(File.join(Config.root, CONFIG_FILE), 'w') do |file|
    file.write(config_to_write.to_yaml)
  end

  load_config!
  puts "Now set S3 keys in #{ENV_FILE}."
  open_env_file_in_editor
  puts "Now configure checks in #{CHECKS_FILE}."
  open_checks_file_in_editor
  puts "Setup completed: created #{CONFIG_FILE}."
end

def check_config_validity
  reload_env!
  s3 = Config.s3
  s3_access_key_id = ENV['S3_ACCESS_KEY'].to_s.strip
  s3_secret_access_key = ENV['S3_SECRET_KEY'].to_s.strip

  missing_keys = []
  missing_keys << 'ENV.S3_ACCESS_KEY' if s3_access_key_id.empty?
  missing_keys << 'ENV.S3_SECRET_KEY' if s3_secret_access_key.empty?
  missing_keys << 's3.region' if s3&.region.to_s.strip.empty?

  if missing_keys.any?
    puts "Invalid configuration. Missing fields: #{missing_keys.join(', ')}"
    exit 1
  end

  puts 'S3 configuration is valid.'
end

def edit_config_file
  create_configuration_file_if_not_exists
  system(editor_command, File.join(Config.root, CONFIG_FILE))
  open_env_file_in_editor
  open_checks_file_in_editor
end

def show_current_config
  reload_env!
  s3 = Config.s3
  has_access_key_id = !ENV['S3_ACCESS_KEY'].to_s.strip.empty?
  has_secret_access_key = !ENV['S3_SECRET_KEY'].to_s.strip.empty?

  puts 'Current configuration:'
  puts "- file default: #{DEFAULT_CONFIG_FILE}"
  puts "- file custom:  #{CONFIG_FILE}#{config_file_exists? ? '' : ' (not present)'}"
  puts "- checks template: #{DEFAULT_CHECKS_FILE}#{File.exist?(default_checks_file_path) ? '' : ' (not present)'}"
  puts "- checks file: #{CHECKS_FILE}#{checks_file_exists? ? '' : ' (not present)'}"
  puts "- env template: #{DEFAULT_ENV_FILE}#{File.exist?(default_env_file_path) ? '' : ' (not present)'}"
  puts '- env (.env):'
  puts "    S3_ACCESS_KEY: #{has_access_key_id ? 'present' : 'missing'}"
  puts "    S3_SECRET_KEY: #{has_secret_access_key ? 'present' : 'missing'}"
  puts '- s3:'
  puts "    region: #{s3&.region}"
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
