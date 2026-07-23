# frozen_string_literal: true

require 'fileutils'

class RunAllChecks < ActiveInteraction::Base

  validate :check_if_already_running

  def execute
    FileUtils.mkdir_p(File.dirname(Config.pid_file_path))
    File.write(Config.pid_file_path, Process.pid)
    at_exit do
      File.delete(Config.pid_file_path) if File.exist?(Config.pid_file_path)
    end

    Aws.config.update(
      region: Config.s3&.region,
      credentials: Aws::Credentials.new(ENV['S3_ACCESS_KEY'], ENV['S3_SECRET_KEY'])
    )

    s3_resource = Aws::S3::Resource.new

    checks_config = load_yaml_file(checks_file_path)
    checks = Array(checks_config['checks'])

    checks.each do |check_group|
      next unless check_group.is_a?(Hash)

      group_name = check_group['name'].to_s.strip
      bucket_name = check_group['bucket'].to_s.strip
      bucket = s3_resource.bucket(bucket_name)

      puts("Running check group: #{group_name}") unless group_name.empty?

      Array(check_group['check']).each do |check_definition|
        next unless check_definition.is_a?(Hash)

        type = check_definition['type'].to_s.strip
        params = check_definition['params'].is_a?(Hash) ? check_definition['params'].transform_keys(&:to_sym) : {}

        klass = interaction_class_for(type)
        klass.run!(params.merge(bucket: bucket))
      end
    end

    # # -----------------------------------------------
    # # Legacy direct calls (kept as reference only)
    # # -----------------------------------------------
    # # Check::FolderNotEmpty.run!(folder_path: "not_empty_folder/", bucket: s3_resource.bucket("test-s3check"))
    # # Check::FilesNotEmpty.run!(files: "not_empty_folder/cereali.svg", bucket: s3_resource.bucket("test-s3check"))
    # # Check::FilesContain.run!(files: "not_empty_folder/cereali.svg", content: "<svg", bucket: s3_resource.bucket("test-s3check"))
    # # Check::FilesCount.run!(files: "not_empty_folder/*.svg", min: 2, max: 2, bucket: s3_resource.bucket("test-s3check"))
    # # Check::FilesSize.run!(files: "not_empty_folder/cereali.svg", min: 2000, max: 3000, bucket: s3_resource.bucket("test-s3check"))
    # # Check::SyntaxCheckFiles.run!(files: "not_empty_folder/*.svg", bucket: s3_resource.bucket("test-s3check"))
    # # ok, will pass.
    # Check::FolderNotEmpty.run!(folder_path: "not_empty_folder/", bucket: s3_resource.bucket("test-s3check"))

    # # won't pass since folder is empty (but exists)
    # # Check::FolderNotEmpty.run!(folder_path: "empty_folder/", bucket: s3_resource.bucket("test-s3check"))

    # # won't pass since folder doesn't exist
    # # Check::FolderNotEmpty.run!(folder_path: "non_existent_folder/", bucket: s3_resource.bucket("test-s3check"))

    # # ###############################################
    # # Check files not empty (> 0 bytes)
    # # ###############################################
    # # Will pass.
    # Check::FilesNotEmpty.run!(files: "not_empty_folder/cereali.svg", bucket: s3_resource.bucket("test-s3check"))

    # # Will fail: gigi.svg is empty.
    # # Check::FilesNotEmpty.run!(files: "not_empty_folder/*.svg", bucket: s3_resource.bucket("test-s3check"))

    # # Will fail: folder doesn't exist.
    # # Check::FilesNotEmpty.run!(files: "non_existent_folder/*.svg", bucket: s3_resource.bucket("test-s3check"))

    # # Will fail: file is empty.
    # # Check::FilesNotEmpty.run!(files: "not_empty_folder/gigi.svg", bucket: s3_resource.bucket("test-s3check"))
    # # Check::FilesNotEmpty.run!(files: "not_empty_folder/gi*.svg", bucket: s3_resource.bucket("test-s3check"))

    # # ###############################################
    # # Check presence of a string inside files
    # # ###############################################
    # # Will pass.
    # Check::FilesContain.run!(files: "not_empty_folder/cereali.svg", content: %(<svg enable-background="new 0 0 110 110" height="512" viewBox="0 0 110 110"), bucket: s3_resource.bucket("test-s3check"))

    # # Will fail: file does not contain the provided string.
    # # Check::FilesContain.run!(files: "not_empty_folder/cereali.svg", content: %(somethinggggg), bucket: s3_resource.bucket("test-s3check"))

    # # Fill fail: file is empty.
    # # Check::FilesContain.run!(files: "not_empty_folder/gigi.svg", content: %(somethinggggg), bucket: s3_resource.bucket("test-s3check"))

    # # Will fail: file does not exist.
    # # Check::FilesContain.run!(files: "not_empty_folder/non_existent_file.svg", content: %(somethinggggg), bucket: s3_resource.bucket("test-s3check"))

    # # ###############################################
    # # Check number of files matching a pattern.
    # # ###############################################
    # # Will pass: 2 files matching the pattern.
    # Check::FilesCount.run!(files: "not_empty_folder/*.svg", min: 2, bucket: s3_resource.bucket("test-s3check"))
    # Check::FilesCount.run!(files: "not_empty_folder/*.svg", max: 2, bucket: s3_resource.bucket("test-s3check"))
    # Check::FilesCount.run!(files: "not_empty_folder/*.svg", min: 2, max: 2, bucket: s3_resource.bucket("test-s3check"))
    # Check::FilesCount.run!(files: "not_empty_folder/*", min: 2, max: 2, bucket: s3_resource.bucket("test-s3check"))

    # # Will fail.
    # # Check::FilesCount.run!(files: "not_empty_folder/*.svg", min: 3, max: 2, bucket: s3_resource.bucket("test-s3check"))
    # # Check::FilesCount.run!(files: "not_empty_folder/*.svg", min: 3, bucket: s3_resource.bucket("test-s3check"))
    # # Check::FilesCount.run!(files: "not_empty_folder/*.svg", max: 1, bucket: s3_resource.bucket("test-s3check"))

    # # ###############################################
    # # Check the size (in bytes) of the files matching a pattern.
    # # ###############################################
    # # Will pass.
    # # cereali.svg is ~2.6KB
    # Check::FilesSize.run!(files: "not_empty_folder/cereali.svg", min: 2000, bucket: s3_resource.bucket("test-s3check"))
    # Check::FilesSize.run!(files: "not_empty_folder/cereali.svg", min: 2000, max: 3000, bucket: s3_resource.bucket("test-s3check"))
    # Check::FilesSize.run!(files: "not_empty_folder/gigi.svg", max: 10, bucket: s3_resource.bucket("test-s3check"))

    # # Will fail.
    # # Check::FilesSize.run!(files: "not_empty_folder/doesnotexist.svg", max: 10, bucket: s3_resource.bucket("test-s3check"))
    # # Check::FilesSize.run!(files: "not_empty_folder", max: 10, bucket: s3_resource.bucket("test-s3check"))
    # # Check::FilesSize.run!(files: "not_empty_folder/cereali.svg", max: 2000, bucket: s3_resource.bucket("test-s3check"))
    # # Check::FilesSize.run!(files: "not_empty_folder/cereali.svg", min: 3000, bucket: s3_resource.bucket("test-s3check"))
    # # Check::FilesSize.run!(files: "not_empty_folder/gigi.svg", min: 10, bucket: s3_resource.bucket("test-s3check"))

    # # ###############################################
    # # Syntax check for the files matching a pattern. Will assume the file is valid based on its extension.
    # # ###############################################
    # # Will pass.
    # Check::SyntaxCheckFiles.run!(files: "not_empty_folder/cereali.svg", bucket: s3_resource.bucket("test-s3check"))
    # Check::SyntaxCheckFiles.run!(files: "not_empty_folder/gigi.svg", bucket: s3_resource.bucket("test-s3check"))
    # Check::SyntaxCheckFiles.run!(files: "not_empty_folder/*.svg", bucket: s3_resource.bucket("test-s3check"))

    # # Will fail:
    # # Check::SyntaxCheckFiles.run!(files: "sql/cereali.sql", bucket: s3_resource.bucket("test-s3check"))
    # # Check::SyntaxCheckFiles.run!(files: "sql/*.sql", bucket: s3_resource.bucket("test-s3check"))
    # # Check::SyntaxCheckFiles.run!(files: "sql/*", bucket: s3_resource.bucket("test-s3check"))

    # # ###############################################
    # # Check SHA512 matching for a file
    # # ###############################################
    # Will pass.
    # Check::FileSha512Match.run!(files: "not_empty_folder/cereali.svg", expected_sha512: "575eccf7c752cec3ed24258685abbdc8066f903004b16794255bd46d69408b13c25a963c5edfc00f19eebf33b9281b6433300321e0e27bce457d617b3385b122", bucket: s3_resource.bucket("test-s3check"))
    # Check::FileSha512Match.run!(files: "not_empty_folder/cerea*.svg", expected_sha512: "575eccf7c752cec3ed24258685abbdc8066f903004b16794255bd46d69408b13c25a963c5edfc00f19eebf33b9281b6433300321e0e27bce457d617b3385b122", bucket: s3_resource.bucket("test-s3check"))
    # Check::FileSha512Match.run!(files: "not_empty_folder/gigi.svg", expected_sha512: "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e", bucket: s3_resource.bucket("test-s3check"))

    # Will not pass:
    # Check::FileSha512Match.run!(files: "not_empty_folder/*.svg", expected_sha512: "invalidsha", bucket: s3_resource.bucket("test-s3check"))
    # Check::FileSha512Match.run!(files: "not_empty_folder/cereali.svg", expected_sha512: "invalidsha", bucket: s3_resource.bucket("test-s3check"))
    # Check::FileSha512Match.run!(files: "not_empty_folder/doesnotexist", expected_sha512: "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e", bucket: s3_resource.bucket("test-s3check"))
    # Check::FileSha512Match.run!(files: "not_empty_folder/doesnotexist", expected_sha512: "invalidsha", bucket: s3_resource.bucket("test-s3check"))
  end

  private

  def interaction_class_for(type)
    case type
    when 'folder_not_empty' then Check::FolderNotEmpty
    when 'files_not_empty' then Check::FilesNotEmpty
    when 'files_contain' then Check::FilesContain
    when 'files_count' then Check::FilesCount
    when 'files_size' then Check::FilesSize
    when 'syntax_check_files' then Check::SyntaxCheckFiles
    when 'file_sha512_match' then Check::FileSha512Match
    else
      raise "Unknown check type: #{type}"
    end
  end

  def check_if_already_running
    return unless IsCheckRunning.run!

    errors.add(:base, "Another instance of the checks is already running. Please stop it before starting a new one.")
  end
end
