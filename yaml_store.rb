require 'yaml'

class YamlStore
  def initialize(file_path)
    @file_path = file_path
    ensure_store_exists
  end

  # Transaction-style block for saving and retrieving data
  def transaction
    data = load_store # Load current data
    yield data         # Allow modifications in block
    save_to_store(data) # Persist the changes
  end

  private

  # Create the YAML file if it doesn't exist
  def ensure_store_exists
    return if File.exist?(@file_path)

    File.write(@file_path, {}.to_yaml)
    puts "[DEBUG] Created new YAML store at #{@file_path}"
  end

  # Load the YAML file data
  def load_store
    YAML.load_file(@file_path) || {}
  rescue Psych::SyntaxError => e
    puts "[ERROR] Failed to load YAML (possibly corrupted): #{e.message}"
    {} # Return an empty hash if the YAML file is corrupted
  end

  # Save the updated data to the YAML file
  def save_to_store(data)
    File.write(@file_path, data.to_yaml)
  end
end