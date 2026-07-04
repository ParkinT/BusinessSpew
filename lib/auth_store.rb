# lib/auth_store.rb
#
# Loads and caches API keys and app settings from S3.
# Refreshed alongside vocabulary on POST /admin/reload.
#
# S3 structure:
#   auth/api_keys.json
#   auth/settings.json
#
require_relative 's3_data_store'

module BusinessSpew
  class AuthStore
    AUTH_KEYS_PATH    = 'auth/api_keys.json'.freeze
    AUTH_SETTINGS_PATH = 'auth/settings.json'.freeze

    def initialize
      @store = S3DataStore.new
      reload!
    end

    def reload!
      @keys     = load_keys
      @settings = load_settings
    end

    def valid_key?(key)
      return false if key.nil? || key.strip.empty?
      entry = @keys.find { |k| k['key'] == key.strip }
      entry && entry['enabled'] == true
    end

    def key_owner(key)
      entry = @keys.find { |k| k['key'] == key.strip }
      entry&.fetch('owner', 'unknown')
    end

    def notify_on_spew?
      @settings.fetch('notify_on_spew', false)
    end

    private

    def load_keys
      data = @store.fetch_data(AUTH_KEYS_PATH)
      if data.is_a?(Hash) && data[:error]
        Notifier.s3_error(operation: 'load api_keys.json', reason: data[:error])
        return []
      end
      data.fetch('keys', [])
    rescue StandardError => e
      Notifier.s3_error(operation: 'load api_keys.json', reason: e.message)
      []
    end

    def load_settings
      data = @store.fetch_data(AUTH_SETTINGS_PATH)
      if data.is_a?(Hash) && data[:error]
        Notifier.s3_error(operation: 'load settings.json', reason: data[:error])
        return {}
      end
      data
    rescue StandardError => e
      Notifier.s3_error(operation: 'load settings.json', reason: e.message)
      {}
    end
  end
end
