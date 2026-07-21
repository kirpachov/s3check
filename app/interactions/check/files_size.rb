# frozen_string_literal: true

module Check
  # Checking that each file matching the pattern has a size within the specified range.
  class FilesSize < ActiveInteraction::Base

    string :files
    integer :min, default: nil
    integer :max, default: nil
    object :bucket, class: Aws::S3::Bucket

    def execute
      # compose(FilesNotEmpty, files: files, bucket: bucket)

      objects = compose(FilesMatching, files: files, bucket: bucket)

      if objects.none?
        errors.add(:base, "No files found in the specified path: #{files}")
        return
      end

      files_out_of_size_range = objects.select do |obj|
        file_size = obj.size
        (min && file_size < min) || (max && file_size > max)
      end

      if files_out_of_size_range.any?
        errors.add(:base, "The following files are out of the specified size range (min: #{min}, max: #{max}): #{files_out_of_size_range.map(&:key).join(', ')}")
      end
    end
  end
end
