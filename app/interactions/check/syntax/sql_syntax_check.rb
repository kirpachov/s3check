# frozen_string_literal: true

module Check
  module Syntax
    class SqlSyntaxCheck < ActiveInteraction::Base

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

        # Perform SQL syntax check
        begin
          validate_sql_file(file.get.body.read)
        rescue StandardError => e
          errors.add(:base, "SQL syntax error in file #{file.key}: #{e.message}")
        end
      end

      private

      def validate_sql_file(sql)
        require "pg_query"

        return if sql.strip.empty?

        PgQuery.parse(sql)

        return true
      rescue Errno::ENOENT
        errors.add(:base, "File not found: #{file_path}")
      rescue PgQuery::ParseError => e
        errors.add(:base, "SQL syntax error in file #{file.key}: #{e.message}")
      rescue Encoding::InvalidByteSequenceError,
            Encoding::UndefinedConversionError => e
        errors.add(:base, "Encoding error in file #{file.key}: #{e.message}")
      end
    end
  end
end
