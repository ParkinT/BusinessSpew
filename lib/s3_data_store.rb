# lib/s3_data_store.rb
require 'aws-sdk-s3'
require 'json'
require 'dotenv/load'

module BusinessSpew
  class S3DataStore
    def initialize
      @s3 = Aws::S3::Client.new(
        region: ENV['AWS_REGION'],
        access_key_id: ENV['AWS_ACCESS_KEY_ID'],
        secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
      )
      @bucket = ENV['AWS_S3_BUCKET']
    end

    def fetch_data(key)
      response = @s3.get_object(bucket: @bucket, key: key)
      JSON.parse(response.body.read)
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
