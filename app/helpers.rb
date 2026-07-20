# frozen_string_literal: true

# Recursively require all files in a directory
def require_recursive(path = File.expand_path(__dir__), pattern = '*.rb')
  # First load recursively files from directories with ascending ordering
  Dir.glob(File.join(path, '*/')).sort.each do |directory|
    require_recursive(directory, pattern)
  end

  # Then load the files with ascending ordering
  Dir.glob(File.join(path, pattern)).sort.each { |file| require file }
end
