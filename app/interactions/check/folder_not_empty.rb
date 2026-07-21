# frozen_string_literal: true

module Check
  class FolderNotEmpty < ActiveInteraction::Base
    string :folder_path

    interface :bucket, methods: [:objects]

    def execute
      # Do complete when: we find a file in the folder or we find the folder and the next element belongs to another folder (meaning the folder is empty)
      bucket.objects.each_with_index do |obj, i|
        if obj.key.start_with?(folder_path) && obj.key != folder_path
          puts "Found file in folder #{folder_path}: #{obj.key}"
          return true
        end
      end

      errors.add(:base, "Folder #{folder_path} not found or it's empty.")
    end
  end
end
