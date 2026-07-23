# frozen_string_literal: true

module Check
  # For the matching files, checks if their content is valid based on the extension of the file.
  class SyntaxCheckFiles < ActiveInteraction::Base

    string :files
    object :bucket, class: Aws::S3::Bucket

    def execute
      objects = compose(FilesMatching, files: files, bucket: bucket)

      objects.each do |obj|
        next if obj.size.zero? # Skip empty files.

        case File.extname(obj.key)
        # when ".json" then compose(Syntax::JsonSyntaxCheck, file: obj)
        # when ".xml" then compose(Syntax::XmlSyntaxCheck, file: obj)
        # when ".yaml", ".yml" then compose(Syntax::YamlSyntaxCheck, file: obj)
        # when ".csv" then compose(Syntax::CsvSyntaxCheck, file: obj)
        # when ".js" then compose(Syntax::JsSyntaxCheck, file: obj)
        when ".json" then compose(Syntax::JsonSyntaxCheck, file: obj)
        when ".svg" then compose(Syntax::SvgSyntaxCheck, file: obj)
        when ".sql" then compose(Syntax::SqlSyntaxCheck, file: obj)
        else
          errors.add(:base, "Unsupported file extension for syntax check: #{obj.key}")
        end
      end
    end
  end
end
