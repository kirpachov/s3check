# frozen_string_literal: true

class CancelRunningChecks < ActiveInteraction::Base
  def execute
    if IsCheckRunning.run!
      pid = File.read(Config.pid_file_path).to_i
      Process.kill("TERM", pid)
      puts "Sent TERM signal to process #{pid}."
    else
      puts "No running process found."
    end
  end
end
