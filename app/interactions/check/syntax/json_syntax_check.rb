# frozen_string_literal: true

module Check
  module Syntax
    class JsonSyntaxCheck < ActiveInteraction::Base

      object :file, class: Aws::S3::ObjectSummary

      def execute
        valid_json?(file.get.body.read)
      end

      private

      def valid_json?(content)
        begin
          require "oj"
          Oj.load(content)
        rescue Oj::ParseError, Errno::ENOENT, Encoding::InvalidByteSequenceError => e
          errors.add(:base, "JSON syntax error in file #{file.key}: #{e.message}")
        end
      end
    end
  end
end
