# frozen_string_literal: true

module Check
  # Checking that each file matching the pattern contains the provided string.
  class FilesContain < ActiveInteraction::Base

    string :files
    string :content
    object :bucket, class: Aws::S3::Bucket

    def execute
      compose(FilesNotEmpty, files: files, bucket: bucket)

      objects = compose(FilesMatching, files: files, bucket: bucket)

      # Check if any of the files do not contain the specified content
      files_without_content = objects.select do |obj|
        file_content = obj.get.body.read
        !file_content.include?(content)
      end

      if files_without_content.any?
        errors.add(:base, "The following files do not contain the specified content '#{content}': #{files_without_content.map(&:key).join(', ')}")
      end
    end
  end
end
