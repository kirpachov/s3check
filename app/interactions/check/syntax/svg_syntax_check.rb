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
        valid_svg?(file.get.body.read)
      end

      private

      def valid_svg?(content)
        begin
          require "nokogiri"

            document = Nokogiri::XML(content) do |config|
              config.strict
                    .nonet
            end

            root = document.root

            return false unless root
            return false unless root.name == "svg"

            valid_namespaces = [
              nil,
              "",
              "http://www.w3.org/2000/svg"
            ]

            return false unless valid_namespaces.include?(root.namespace&.href)

            true
        rescue Nokogiri::XML::SyntaxError, Errno::ENOENT, Encoding::InvalidByteSequenceError => e
          errors.add(:base, "SVG syntax error in file #{file.key}: #{e.message}")
        end
      end
    end
  end
end
