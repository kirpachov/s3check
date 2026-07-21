# frozen_string_literal: true

module Check
  class FilesNotEmpty < ActiveInteraction::Base

    # TODO pattern matching tipo:
    # - not_empty_folder/*.svg
    # - not_empty_folder/cereali.svg
    # - non_existent_folder/*.svg|non_existent_folder/*.png: all files inside the folder with .svg or .png extension
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
