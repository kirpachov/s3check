# frozen_string_literal: true

require 'logger'
require "rainbow"
require "rainbow/ext/string"


def get_severity_color(severity)
  color = :blue
  case severity
  when 'DEBUG'
    color = "#512DA8"
  when 'INFO'
    color = "#33691E"
  when 'WARN'
    color = "#E65100"
  when 'ERROR', 'FATAL'
    color = "#B71C1C"
  else
    color = "#00BCD4"
  end

  return color
end

###############################################
# Configurazione logger da usare di default
###############################################
DEFAULT_LOGGER = Logger.new(STDOUT)
DEFAULT_LOGGER.level = Logger::DEBUG
DEFAULT_LOGGER.formatter = proc do |severity, datetime, progname, msg|
  "[#{datetime.strftime('%F %T.%L')}]".color(:cyan) + "(#{$$})".color(:blue) + "|#{severity}|".color(get_severity_color(severity)) +
  (progname ? "<#{progname}>".color(:yellow) : "")  + " #{msg}\n"
end

def logger
  return DEFAULT_LOGGER
end

###############################################
# Configurazione del logger da usare per
# loggare le query
###############################################
DB_LOGGER = Logger.new(STDOUT)
DB_LOGGER.level = Logger::DEBUG
DB_LOGGER.progname = "SQL"
DB_LOGGER.formatter = proc do |severity, datetime, progname, msg|
  "[#{datetime.strftime('%F %T.%L')}]".color(:cyan) + "(#{$$})".color(:blue) + "|#{severity}|".color(get_severity_color(severity)) +
  (progname ? "<#{progname}>".color(:yellow) : "")  + " #{msg.color(:magenta)}\n"
end

