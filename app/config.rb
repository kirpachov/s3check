# frozen_string_literal: true

require 'configatron'
require 'dotenv/load'
require 'yaml'
require 'aws-sdk-core'

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

Aws.config.update(
  region: Config.s3&.region,
  credentials: Aws::Credentials.new(ENV['S3_ACCESS_KEY'], ENV['S3_SECRET_KEY'])
)

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

def load_yaml_file(file_path)
  YAML.load_file(file_path) || {}
rescue Psych::SyntaxError => e
  { '__yaml_error__' => e.message }
end

def available_check_types
  Dir.glob(File.join(Config.root, 'app/interactions/check/*.rb')).map do |path|
    File.basename(path, '.rb')
  end
end

def required_paths_from_template(example_hash)
  checks = example_hash['checks']
  return [] unless checks.is_a?(Array) && checks.first.is_a?(Hash)

  template_group = checks.first
  paths = []

  paths << ['name'] if template_group.key?('name')
  paths << ['bucket'] if template_group.key?('bucket')

  template_check = Array(template_group['check']).first
  if template_check.is_a?(Hash)
    paths << ['check', '[]', 'type'] if template_check.key?('type')

    template_params = template_check['params']
    if template_params.is_a?(Hash)
      template_params.keys.each do |param_key|
        paths << ['check', '[]', 'params', param_key]
      end
    end
  end

  paths
end

def value_present_for_path?(source_hash, path)
  current = source_hash

  path.each_with_index do |segment, index|
    if segment == '[]'
      return false unless current.is_a?(Array) && current.any?

      remaining_path = path[(index + 1)..]
      return current.any? { |item| value_present_for_path?(item, remaining_path) }
    end

    return false unless current.is_a?(Hash) && current.key?(segment)

    current = current[segment]
  end

  !current.to_s.strip.empty?
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

  validation_errors = []
  validation_errors << 'ENV.S3_ACCESS_KEY is missing' if s3_access_key_id.empty?
  validation_errors << 'ENV.S3_SECRET_KEY is missing' if s3_secret_access_key.empty?
  validation_errors << 's3.region is missing' if s3&.region.to_s.strip.empty?

  unless checks_file_exists?
    validation_errors << "#{CHECKS_FILE} is missing"
  end

  checks_hash = checks_file_exists? ? load_yaml_file(checks_file_path) : {}
  if checks_hash.key?('__yaml_error__')
    validation_errors << "#{CHECKS_FILE} has invalid YAML format"
  else
    checks = checks_hash['checks']
    validation_errors << "#{CHECKS_FILE}: checks must be a non-empty array" unless checks.is_a?(Array) && checks.any?

    checks_example_hash = load_yaml_file(default_checks_file_path)
    if checks_example_hash.key?('__yaml_error__')
      validation_errors << "#{DEFAULT_CHECKS_FILE} has invalid YAML format"
    else
      required_paths = required_paths_from_template(checks_example_hash)

      checks.each_with_index do |check_group, index|
        next unless check_group.is_a?(Hash)
        next if check_group['name'].to_s.strip.empty?

        required_paths.each do |path|
          next if value_present_for_path?(check_group, path)

          validation_errors << "#{CHECKS_FILE}: checks[#{index}] missing #{path.join('.').gsub('.[]', '[]')}"
        end

        Array(check_group['check']).each_with_index do |single_check, check_index|
          next unless single_check.is_a?(Hash)

          type = single_check['type'].to_s.strip
          if type.end_with?('.rb')
            validation_errors << "#{CHECKS_FILE}: checks[#{index}].check[#{check_index}].type must be interaction name without .rb"
            next
          end

          next if available_check_types.include?(type)

          validation_errors << "#{CHECKS_FILE}: checks[#{index}].check[#{check_index}].type '#{type}' is not valid. Allowed: #{available_check_types.join(', ')}"
        end
      end
    end
  end

  if validation_errors.any?
    puts "Invalid configuration:\n- #{validation_errors.join("\n- ")}"
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
