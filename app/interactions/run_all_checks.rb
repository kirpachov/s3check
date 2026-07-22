# frozen_string_literal: true

class RunAllChecks < ActiveInteraction::Base

  validate :check_if_already_running

  def execute
    File.write(Config.pid_file_path, Process.pid)
    at_exit do
      File.delete(Config.pid_file_path) if File.exist?(Config.pid_file_path)
    end

    s3_resource = Aws::S3::Resource.new

    # TODO diego
    # Config.checks.each do |check|
    #   klass = case check[:type]
    #           when "folder_not_empty"
    #             Check::FolderNotEmpty
    #           when "files_not_empty"
    #             Check::FilesNotEmpty
    #           when "files_contain"
    #             Check::FilesContain
    #           when "files_count"
    #             Check::FilesCount
    #           when "files_size"
    #             Check::FilesSize
    #           when "syntax_check_files"
    #             Check::SyntaxCheckFiles
    #           else
    #             raise "Unknown check type: #{check[:type]}"
    #           end

    #   klass.run!(check[:params].merge(bucket: s3_resource.bucket(check[:bucket])))
    # end

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
    # Check::FilesNotEmpty.run!(files: "not_empty_folder/gi*.svg", bucket: s3_resource.bucket("test-s3check"))

    # ###############################################
    # Check presence of a string inside files
    # ###############################################
    # Will pass.
    Check::FilesContain.run!(files: "not_empty_folder/cereali.svg", content: %(<svg enable-background="new 0 0 110 110" height="512" viewBox="0 0 110 110"), bucket: s3_resource.bucket("test-s3check"))

    # Will fail: file does not contain the provided string.
    # Check::FilesContain.run!(files: "not_empty_folder/cereali.svg", content: %(somethinggggg), bucket: s3_resource.bucket("test-s3check"))

    # Fill fail: file is empty.
    # Check::FilesContain.run!(files: "not_empty_folder/gigi.svg", content: %(somethinggggg), bucket: s3_resource.bucket("test-s3check"))

    # Will fail: file does not exist.
    # Check::FilesContain.run!(files: "not_empty_folder/non_existent_file.svg", content: %(somethinggggg), bucket: s3_resource.bucket("test-s3check"))

    # ###############################################
    # Check number of files matching a pattern.
    # ###############################################
    # Will pass: 2 files matching the pattern.
    Check::FilesCount.run!(files: "not_empty_folder/*.svg", min: 2, bucket: s3_resource.bucket("test-s3check"))
    Check::FilesCount.run!(files: "not_empty_folder/*.svg", max: 2, bucket: s3_resource.bucket("test-s3check"))
    Check::FilesCount.run!(files: "not_empty_folder/*.svg", min: 2, max: 2, bucket: s3_resource.bucket("test-s3check"))
    Check::FilesCount.run!(files: "not_empty_folder/*", min: 2, max: 2, bucket: s3_resource.bucket("test-s3check"))

    # Will fail.
    # Check::FilesCount.run!(files: "not_empty_folder/*.svg", min: 3, max: 2, bucket: s3_resource.bucket("test-s3check"))
    # Check::FilesCount.run!(files: "not_empty_folder/*.svg", min: 3, bucket: s3_resource.bucket("test-s3check"))
    # Check::FilesCount.run!(files: "not_empty_folder/*.svg", max: 1, bucket: s3_resource.bucket("test-s3check"))

    # ###############################################
    # Check the size (in bytes) of the files matching a pattern.
    # ###############################################
    # Will pass.
    # cereali.svg is ~2.6KB
    Check::FilesSize.run!(files: "not_empty_folder/cereali.svg", min: 2000, bucket: s3_resource.bucket("test-s3check"))
    Check::FilesSize.run!(files: "not_empty_folder/cereali.svg", min: 2000, max: 3000, bucket: s3_resource.bucket("test-s3check"))
    Check::FilesSize.run!(files: "not_empty_folder/gigi.svg", max: 10, bucket: s3_resource.bucket("test-s3check"))

    # Will fail.
    # Check::FilesSize.run!(files: "not_empty_folder/doesnotexist.svg", max: 10, bucket: s3_resource.bucket("test-s3check"))
    # Check::FilesSize.run!(files: "not_empty_folder", max: 10, bucket: s3_resource.bucket("test-s3check"))
    # Check::FilesSize.run!(files: "not_empty_folder/cereali.svg", max: 2000, bucket: s3_resource.bucket("test-s3check"))
    # Check::FilesSize.run!(files: "not_empty_folder/cereali.svg", min: 3000, bucket: s3_resource.bucket("test-s3check"))
    # Check::FilesSize.run!(files: "not_empty_folder/gigi.svg", min: 10, bucket: s3_resource.bucket("test-s3check"))

    # ###############################################
    # Syntax check for the files matching a pattern. Will assume the file is valid based on its extension.
    # ###############################################
    # Will pass.
    Check::SyntaxCheckFiles.run!(files: "not_empty_folder/cereali.svg", bucket: s3_resource.bucket("test-s3check"))
    Check::SyntaxCheckFiles.run!(files: "not_empty_folder/gigi.svg", bucket: s3_resource.bucket("test-s3check"))
    Check::SyntaxCheckFiles.run!(files: "not_empty_folder/*.svg", bucket: s3_resource.bucket("test-s3check"))

    # Will fail:
    # Check::SyntaxCheckFiles.run!(files: "sql/cereali.sql", bucket: s3_resource.bucket("test-s3check"))
    # Check::SyntaxCheckFiles.run!(files: "sql/*.sql", bucket: s3_resource.bucket("test-s3check"))
    # Check::SyntaxCheckFiles.run!(files: "sql/*", bucket: s3_resource.bucket("test-s3check"))

    # ###############################################
    # Check SHA512 matching for a file
    # ###############################################
  end

  private

  def check_if_already_running
    return unless IsCheckRunning.run!

    errors.add(:base, "Another instance of the checks is already running. Please stop it before starting a new one.")
  end
end
