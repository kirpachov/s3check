# frozen_string_literal: true

class IsCheckRunning < ActiveInteraction::Base
  def execute
    if File.exist?(Config.pid_file_path)
      pid = File.read(Config.pid_file_path).to_i
      begin
        Process.getpgid(pid)
        true
      rescue Errno::ESRCH
        false
      end
    else
      false
    end
  end
end
