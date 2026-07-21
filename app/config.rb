# frozen_string_literal: true

require 'configatron'
require 'yaml'

DEFAULT_CONFIG_FILE = 'config/app.example.yml'
CONFIG_FILE = 'config/app.yml'

Config = configatron
Config.root = File.absolute_path(File.expand_path('..', __dir__))

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

def config_file_exists?
  File.exist?(File.join(Config.root, CONFIG_FILE))
end

def create_configuration_file_if_not_exists
  return if config_file_exists?

  puts "Configurazione non trovata (#{CONFIG_FILE})."
  puts 'Avvio installazione guidata per Amazon S3...'

  print 'S3 access_key_id: '
  access_key_id = STDIN.gets&.chomp.to_s

  print 'S3 secret_access_key: '
  secret_access_key = STDIN.gets&.chomp.to_s

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
      'access_key_id' => access_key_id,
      'secret_access_key' => secret_access_key,
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

  missing_keys = []
  missing_keys << 's3.access_key_id' if s3&.access_key_id.to_s.strip.empty?
  missing_keys << 's3.secret_access_key' if s3&.secret_access_key.to_s.strip.empty?
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
  masked_secret = s3&.secret_access_key.to_s.empty? ? '' : '******'

  puts 'Configurazione in uso:'
  puts "- file default: #{DEFAULT_CONFIG_FILE}"
  puts "- file custom:  #{CONFIG_FILE}#{config_file_exists? ? '' : ' (non presente)'}"
  puts '- s3:'
  puts "    access_key_id: #{s3&.access_key_id}"
  puts "    secret_access_key: #{masked_secret}"
  puts "    region: #{s3&.region}"
  puts "    bucket: #{s3&.bucket}"
  puts "    endpoint: #{s3&.endpoint}"
  puts "    backup_prefix: #{s3&.backup_prefix}"
end

USAGE_MESSAGE = <<~DOC
  Usage:

  ruby #{$PROGRAM_NAME} <command>

  Commands:
  - help | -h            Mostra questo aiuto
  - version | -v         Mostra versione
  - console | c          Apre console Pry
  - config-check | cc    Valida configurazione S3
  - config-edit | ce     Apre config/app.yml nell'editor
  - config-show | cs     Mostra configurazione effettiva (secret mascherata)
  - run | start          Avvia checks (crea config/app.yml se manca)
  - stop | halt          Ferma i checks
DOC

def print_help_message
  puts USAGE_MESSAGE
end

load_config!
