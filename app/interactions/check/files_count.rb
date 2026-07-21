# frozen_string_literal: true

module Check
  # Validates number of files matching the pattern is between min and max.
  class FilesCount < ActiveInteraction::Base

    # #################
    # Inputs
    # #################
    string :files
    integer :min, default: nil
    integer :max, default: nil
    object :bucket, class: Aws::S3::Bucket

    # #################
    # Validations
    # #################
    validates :min, numericality: { greater_than_or_equal_to: 0 }, if: -> { min.present? }
    validates :max, numericality: { greater_than_or_equal_to: 0 }, if: -> { max.present? }
    validate :min_less_than_max
    validate :either_min_or_max_present

    # #################
    # Main
    # #################
    def execute
      objects = compose(FilesMatching, files: files, bucket: bucket)

      errors.add(:base, "Number of files (#{objects.size}) is less than the minimum allowed (#{min})") if min && objects.size < min
      errors.add(:base, "Number of files (#{objects.size}) is greater than the maximum allowed (#{max})") if max && objects.size > max

      errors.empty?
    end

    private

    # #################
    # Utils Validations
    # #################

    def min_less_than_max
      return if min.nil? || max.nil?
      return if min <= max

      errors.add(:base, "Minimum number of files (#{min}) cannot be greater than maximum (#{max})")
    end

    def either_min_or_max_present
      return if min.present? || max.present?

      errors.add(:base, "Either minimum or maximum number of files must be specified")
    end
  end
end
