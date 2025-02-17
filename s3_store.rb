require 'yaml'

class S3Store
  def initialize(bucket_name, region)
    @bucket_name = bucket_name
    @s3 = Aws::S3::Resource.new(region: region)
  end

  # Mimic transaction-like functionality for loading and saving YAML content
  def transaction(key = 'store.yml')
    data = load_store(key) # Load data from S3
    yield data             # Let the caller modify it
    save_to_store(key, data) # Save the updated data back to S3
  end

  # Retrieve a file's content from S3 as a Ruby object
  def load_store(key)
    yaml_data = get_object(key)
    YAML.safe_load(yaml_data, permitted_classes: [Hash, Array, String, Symbol], symbolize_names: true) || {}
  rescue Psych::SyntaxError => e
    puts "[ERROR] Failed to parse YAML from S3: #{e.message}"
    {}
  end

  # Save Ruby object as YAML content to S3
  def save_to_store(key, data)
    yaml_data = data.to_yaml
    put_object(key, yaml_data)
  end

  # Retrieve raw file content from S3
  def get_object(key)
    obj = @s3.bucket(@bucket_name).object(key)
    obj.get.body.read
  rescue Aws::S3::Errors::NoSuchKey
    puts "[WARN] Key not found: #{key}"
    nil
  end

  # Save/update a file in S3
  def put_object(key, content)
    @s3.bucket(@bucket_name).object(key).put(body: content)
    puts "[INFO] Uploaded file with key: #{key} to bucket: #{@bucket_name}"
  end

  # List all objects in the bucket
  def list_objects
    @s3.bucket(@bucket_name).objects.map(&:key)
  end
end