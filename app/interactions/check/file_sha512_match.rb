# frozen_string_literal: true

module Check
  class FileSha512Match < ActiveInteraction::Base

    string :files
    string :expected_sha512
    object :bucket, class: Aws::S3::Bucket

    def execute
      objects = compose(FilesMatching, files: files, bucket: bucket)

      if objects.none?
        errors.add(:base, "No files found in the specified path: #{files}")
        return
      end

      # Check if any of the files do not match the expected SHA-512 hash
      mismatched_files = objects.select do |obj|
        obj_sha512 = Digest::SHA512.hexdigest(obj.get.body.read)
        obj_sha512 != expected_sha512
      end

      if mismatched_files.any?
        errors.add(:base, "The following files do not match the expected SHA-512 hash: #{mismatched_files.map(&:key).join(', ')}")
      end
    end
  end
end
