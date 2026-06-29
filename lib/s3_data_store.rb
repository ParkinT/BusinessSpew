require 'aws-sdk-s3'
require 'json'

module BusinessSpew
  class S3DataStore
    def initialize
      @s3 = Aws::S3::Client.new(
        region: ENV['AWS_REGION'],
        credentials: {
          access_key_id: ENV['AWS_ACCESS_KEY_ID'],
          secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
        }
      )
      @bucket = ENV['AWS_S3_BUCKET']
    end
    
    def fetch_data(key)
      begin
        response = @s3.get_object(bucket: @bucket, key: key)
        JSON.parse(response.body.string)
      rescue StandardError => e
        { error: "S3 Error: #{e.message}" }
      end
    end
    
    # Test suite
    module Tests
      def self.run_all
        puts "\nRunning S3 Data Store Tests..."
        
        test 'Fetching existing key' do
          result = @store.fetch_data('test/example.json')
          puts "Test 1: #{result[:error] || 'PASSED'}"
        end
        
        test 'Fetching non-existent key' do
          result = @store.fetch_data('nonexistent/key.json')
          puts "Test 2: #{result[:error] || 'PASSED'}"
        end
        
        test 'Invalid credentials' do
          invalid_store = S3DataStore.new(
            access_key: 'invalid',
            secret_key: 'invalid'
          )
          result = invalid_store.fetch_data('test/example.json')
          puts "Test 3: #{result[:error] || 'PASSED'}"
        end
      end
    end
  end
end

