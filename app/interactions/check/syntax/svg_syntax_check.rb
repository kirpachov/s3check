# frozen_string_literal: true

module Check
  module Syntax
    class SvgSyntaxCheck < ActiveInteraction::Base

      object :file, class: Aws::S3::ObjectSummary
      # #<Aws::S3::ObjectSummary:0x00007cd03393f500
      #  @bucket_name="test-s3check",
      #  @client=#<Aws::S3::Client>,
      #  @data=
      #   #<struct Aws::S3::Types::Object
      #    key="not_empty_folder/cereali.svg",
      #    last_modified=2026-07-21 13:16:40 UTC,
      #    etag="\"1d358e8cff803bfc2618cf5187b9330b\"",
      #    checksum_algorithm=["CRC64NVME"],
      #    checksum_type="FULL_OBJECT",
      #    size=2654,
      #    storage_class="STANDARD",
      #    owner=nil,
      #    restore_status=nil>,
      #  @key="not_empty_folder/cereali.svg",
      #  @waiter_block_warned=false>


      def execute
        # Read the file content from S3
        file_content = file.get.body.read

        # Perform SVG syntax check
        begin
          # Use an SVG parser or validator to check the syntax
          # For example, you can use the 'nokogiri' gem
          # doc = Nokogiri::XML(file_content) { |config| config.strict }
          # If parsing is successful, the syntax is valid
        rescue StandardError => e
          errors.add(:base, "SVG syntax error in file #{file.key}: #{e.message}")
        end
      end
    end
  end
end
