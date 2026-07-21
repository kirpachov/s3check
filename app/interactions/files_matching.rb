# frozen_string_literal: true

# Smart file matching algorythm that can handle patterns like:
# - not_empty_folder/*.svg
# - not_empty_folder/cereali.svg
class FilesMatching < ActiveInteraction::Base
  string :files
  object :bucket, class: Aws::S3::Bucket

  def execute
    objects
  end

  def objects
    return @objects if defined?(@objects)

    @objects = bucket.objects(prefix: files.sub(/\*.*$/, ''))
    @objects = @objects.select { |obj| File.fnmatch(files, obj.key) }
    @objects = @objects.reject { |obj| obj.key.end_with?('/') }
    @objects
  end
end
