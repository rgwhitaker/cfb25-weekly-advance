require 'aws-sdk-s3'

class S3Store
  def initialize(bucket_name, region)
    @bucket_name = bucket_name
    @s3 = Aws::S3::Resource.new(region: region) # AWS SDK detects credentials via environment variables
  end

  # Retrieve an object from the S3 bucket
  def get_object(key)
    obj = @s3.bucket(@bucket_name).object(key)
    obj.get.body.read
  rescue Aws::S3::Errors::NoSuchKey
    puts "[WARN] Key not found: #{key}"
    nil
  end

  # Save or update an object in the bucket
  def put_object(key, content)
    @s3.bucket(@bucket_name).object(key).put(body: content)
    puts "[INFO] Uploaded file with key: #{key} to bucket: #{@bucket_name}"
  end

  # List all objects in the bucket
  def list_objects
    @s3.bucket(@bucket_name).objects.map(&:key)
  end
end