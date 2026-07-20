# lib/s3_data_store.rb
require 'aws-sdk-s3'
require 'json'
require 'openssl'
require 'base64'
require 'dotenv/load'

module BusinessSpew
  class S3DataStore
    # Prefix that marks an AES-256-GCM encrypted blob.
    # Plain JSON files (no prefix) are still readable for backward compat.
    ENCRYPTED_PREFIX = 'ENC1:'.freeze

    def initialize
      @s3 = Aws::S3::Client.new(
        region: ENV['AWS_REGION'],
        access_key_id: ENV['AWS_ACCESS_KEY_ID'],
        secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
      )
      @bucket = ENV['AWS_S3_BUCKET']
    end

    # Fetch an object from S3 and return it as a Ruby Hash/Array.
    # Transparently decrypts if the content was written by store_data.
    def fetch_data(key)
      raw = @s3.get_object(bucket: @bucket, key: key).body.read
      raw.start_with?(ENCRYPTED_PREFIX) ? decrypt_json(raw) : JSON.parse(raw)
    rescue StandardError => e
      { error: "S3 Error: #{e.message}" }
    end

    # Encrypt data_hash and write it to S3.
    def store_data(key, data_hash)
      @s3.put_object(
        bucket: @bucket,
        key: key,
        body: encrypt_json(data_hash),
        content_type: 'application/octet-stream',
        server_side_encryption: 'AES256'
      )
    rescue StandardError => e
      { error: "S3 Error: #{e.message}" }
    end

  def fetch_all_vocabulary
    resp = @s3.list_objects_v2(bucket: @bucket, prefix: 'lexicon/')
    
    resp.contents.each_with_object({}) do |obj, vocab|
      data = fetch_data(obj.key)
      next if data.is_a?(Hash) && data[:error]
      
      category = data['category']
      vocab[category] = {
        'nouns'      => data['nouns']      || [],
        'verbs'      => data['verbs']      || [],
        'connectors' => data['connectors'] || [],
        'prefixes'   => data['prefixes']   || []
      }
    end
  end

    private

    # Returns a 32-byte key derived from the S3_ENCRYPTION_KEY env var (64-char hex).
    def encryption_key
      hex = ENV['S3_ENCRYPTION_KEY']
      raise 'S3_ENCRYPTION_KEY is not set' if hex.nil? || hex.strip.empty?
      raise 'S3_ENCRYPTION_KEY must be a 64-character hex string' unless hex.match?(/\A[0-9a-fA-F]{64}\z/)
      [hex].pack('H*')
    end

    # AES-256-GCM encrypt: returns "ENC1:<base64(iv+tag+ciphertext)>"
    def encrypt_json(data_hash)
      cipher = OpenSSL::Cipher.new('aes-256-gcm')
      cipher.encrypt
      iv            = cipher.random_iv   # 12 bytes
      cipher.key    = encryption_key
      cipher.auth_data = ''
      ciphertext    = cipher.update(data_hash.to_json) + cipher.final
      tag           = cipher.auth_tag    # 16 bytes
      "#{ENCRYPTED_PREFIX}#{Base64.strict_encode64(iv + tag + ciphertext)}"
    end

    # AES-256-GCM decrypt: accepts the string produced by encrypt_json.
    def decrypt_json(raw)
      payload    = Base64.strict_decode64(raw[ENCRYPTED_PREFIX.length..])
      iv         = payload[0, 12]
      tag        = payload[12, 16]
      ciphertext = payload[28..]
      cipher = OpenSSL::Cipher.new('aes-256-gcm')
      cipher.decrypt
      cipher.key      = encryption_key
      cipher.iv       = iv
      cipher.auth_tag = tag
      cipher.auth_data = ''
      JSON.parse(cipher.update(ciphertext) + cipher.final)
    end

    public

    module Tests
      def self.run_all
        store = BusinessSpew::S3DataStore.new

        puts "\n=== S3 Read Validation ==="
        puts "Bucket: #{ENV['AWS_S3_BUCKET']}"
        puts "Region: #{ENV['AWS_REGION']}\n\n"

        # Test 1: List what's actually in lexicon/ so you know what keys exist
        puts "Test 1: Listing keys under lexicon/..."
        s3 = Aws::S3::Client.new(
          region: ENV['AWS_REGION'],
          access_key_id: ENV['AWS_ACCESS_KEY_ID'],
          secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
        )
        resp = s3.list_objects_v2(bucket: ENV['AWS_S3_BUCKET'], prefix: 'lexicon/')
        keys = resp.contents.map(&:key)
        if keys.empty?
          puts "  No objects found under lexicon/ — check bucket name and prefix"
        else
          puts "  Found: #{keys.join(', ')}"
        end

        # Test 2: Fetch all vocabulary topics
	result = store.fetch_all_vocabulary
	pp result

        # Test 3: Confirm graceful failure on a bad key
        puts "\nTest 3: Fetching nonexistent key..."
        result = store.fetch_data('lexicon/does_not_exist.json')
        if result.is_a?(Hash) && result[:error]
          puts "  PASSED: Error handled gracefully — #{result[:error]}"
        else
          puts "  UNEXPECTED: Got a result for a nonexistent key"
        end
      end
    end
  end
end

if __FILE__ == $0
  BusinessSpew::S3DataStore::Tests.run_all
end
