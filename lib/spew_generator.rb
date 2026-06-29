# lib/spew_generator.rb
require 'aws-sdk-s3'

module SpewGenerator
  extend self
  
  # Use environment variables for credentials
  S3_CONFIG = {
    region: 'us-east-1',
    logger: nil,
    http_continue_timeout: 2,
    http_open_timeout: 2,
    http_read_timeout: 30,
    http_write_timeout: 15
  }.merge!({
    access_key_id: ENV['AWS_ACCESS_KEY_ID'],
    secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
  })

  def s3_client
    @s3_client ||= Aws::S3::Client.new(S3_CONFIG)
  end
  
  # Example method to get vocabulary from S3
  def load_vocabulary_from_s3(key_path = 'vocabulary.json')
    begin
      response = s3_client.get_object(bucket: ENV['S3_BUCKET'], key: key_path)
      JSON.parse(response.body.read)
    rescue StandardError => e
      Rails.logger.error "S3 Error: #{e.message}"
      load_local_vocabulary # fallback to local file
    end
  end
  
  private
  
  def load_local_vocabulary
    # Fallback to local vocabulary if S3 unavailable
    require_relative 'vocabulary'
    Vocabulary
  end
end

