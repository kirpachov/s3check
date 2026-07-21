# frozen_string_literal: true

class RunAllChecks < ActiveInteraction::Base

  validate :check_if_already_running

  def execute
    File.write(Config.pid_file_path, Process.pid)
    at_exit do
      File.delete(Config.pid_file_path) if File.exist?(Config.pid_file_path)
    end

    s3_resource = Aws::S3::Resource.new
    # ###############################################
    # Check folder not empty
    # ###############################################

    # ok, will pass.
    Check::FolderNotEmpty.run!(folder_path: "not_empty_folder/", bucket: s3_resource.bucket("test-s3check"))

    # won't pass since folder is empty (but exists)
    # Check::FolderNotEmpty.run!(folder_path: "empty_folder/", bucket: s3_resource.bucket("test-s3check"))

    # won't pass since folder doesn't exist
    # Check::FolderNotEmpty.run!(folder_path: "non_existent_folder/", bucket: s3_resource.bucket("test-s3check"))


    # ###############################################
    # Check files not empty (> 0 bytes)
    # ###############################################
    # Will pass.
    Check::FilesNotEmpty.run!(files: "not_empty_folder/cereali.svg", bucket: s3_resource.bucket("test-s3check"))

    # Will fail: gigi.svg is empty.
    # Check::FilesNotEmpty.run!(files: "not_empty_folder/*.svg", bucket: s3_resource.bucket("test-s3check"))

    # Will fail: folder doesn't exist.
    # Check::FilesNotEmpty.run!(files: "non_existent_folder/*.svg", bucket: s3_resource.bucket("test-s3check"))

    # Will fail: file is empty.
    # Check::FilesNotEmpty.run!(files: "not_empty_folder/gigi.svg", bucket: s3_resource.bucket("test-s3check"))
  end

  private

  def check_if_already_running
    return unless IsCheckRunning.run!

    errors.add(:base, "Another instance of the checks is already running. Please stop it before starting a new one.")
  end
end
