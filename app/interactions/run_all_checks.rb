# frozen_string_literal: true

class RunAllChecks < ActiveInteraction::Base

  validate :check_if_already_running

  def execute
    File.write(Config.pid_file_path, Process.pid)
    at_exit do
      File.delete(Config.pid_file_path) if File.exist?(Config.pid_file_path)
    end

    puts "TODO read configs, and for each config, run the checks."

    sleep 5
    i = 0
    while true
      puts "Running checks... #{i += 1}"
      sleep 5
    end
  end

  private

  def check_if_already_running
    return unless IsCheckRunning.run!

    errors.add(:base, "Another instance of the checks is already running. Please stop it before starting a new one.")
  end
end
