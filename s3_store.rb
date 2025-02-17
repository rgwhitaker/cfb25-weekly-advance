require 'yaml'
require 'aws-sdk-s3'

class S3Store
  def initialize(bucket_name, region)
    @bucket_name = bucket_name
    @s3 = Aws::S3::Resource.new(region: region)

    # Load the existing store or initialize it as empty
    @data = load_store('store.yml') || {}
  end

  # Mimic transaction behavior for backward compatibility
  def transaction(key = 'store.yml')
    yield @data # Pass the in-memory store to the block for modification
    save_to_store(key, @data) # Save back to S3 after modifications
  end

  # Adding hash-like access methods
  def [](key)
    @data[key] # Access the in-memory data by key
  end

  def []=(key, value)
    @data[key] = value # Modify the in-memory data
    save_to_store('store.yml', @data) # Persist changes to S3 immediately
  end

  def load_store(key)
    yaml_data = get_object(key) || ''
    YAML.safe_load(yaml_data, permitted_classes: [Hash, Array, String, Symbol], symbolize_names: true)
  rescue Psych::SyntaxError => e
    puts "[ERROR] Failed to parse YAML from S3: #{e.message}"
    {}
  end

  def save_to_store(key, data)
    yaml_data = data.to_yaml
    put_object(key, yaml_data)
  end

  def get_object(key)
    obj = @s3.bucket(@bucket_name).object(key)
    obj.get.body.read
  rescue Aws::S3::Errors::NoSuchKey
    puts "[WARN] Key not found: #{key}"
    nil
  end

  def put_object(key, content)
    @s3.bucket(@bucket_name).object(key).put(body: content)
    puts "[INFO] Uploaded file with key: #{key} to bucket: #{@bucket_name}"
  end

  def list_objects
    @s3.bucket(@bucket_name).objects.map(&:key)
  end
end