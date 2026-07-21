# frozen_string_literal: true

module Check
  class FilesNotEmpty < ActiveInteraction::Base

    string :files
    object :bucket, class: Aws::S3::Bucket

    def execute
      # Check if the folder exists in the S3 bucket
      objects = bucket.objects(prefix: files.sub(/\*.*$/, '')) # Remove the asterisk and anything after it for prefix search

      if objects.none?
        errors.add(:base, "No files found in the specified path: #{files}")
        return
      end

      # Check if any of the files are empty
      empty_files = objects.select { |obj| obj.size.zero? }
      if empty_files.any?
        errors.add(:base, "The following files are empty: #{empty_files.map(&:key).join(', ')}")
      end
    end
  end
end
