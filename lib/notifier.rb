# lib/notifier.rb
#
# Lightweight ntfy.sh notification wrapper.
# All events are fire-and-forget — failures are written to stderr
# (captured by Fly.io's log stream) and never propagate to the caller.
#
# Usage:
#   Notifier.send(title: "Deploy complete", message: "businessspew is live")
#   Notifier.invite_redeemed(code: "abc4441", ip: "98.1.2.3")
#
require 'net/http'
require 'uri'
require 'json'

module Notifier
  extend self

  TOPIC    = 'leveraged_synergies'.freeze
  BASE_URL = "https://ntfy.sh/#{TOPIC}".freeze

  PRIORITY = {
    low:     'low',
    default: 'default',
    high:    'high',
    urgent:  'urgent'
  }.freeze

  # ── Generic send ───────────────────────────────────────────────────
  def send(title:, message:, priority: :default, tags: [])
    uri  = URI(BASE_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 3
    http.read_timeout = 5

    req = Net::HTTP::Post.new(uri)
    req['Title']            = title
    req['Priority']         = PRIORITY.fetch(priority, 'default')
    req['Tags']             = tags.join(',') unless tags.empty?
    req['Content-Type']     = 'text/plain'
    req.body                = message

    http.request(req)

  rescue StandardError => e
    warn "[Notifier] Failed to deliver '#{title}': #{e.class} — #{e.message}"
  end

  # ── Named events ───────────────────────────────────────────────────

  def invite_redeemed(code:, ip: 'unknown')
    send(
      title:    '🎟️  Invite Code Redeemed',
      message:  "Code: #{code}\nIP:   #{ip}\nTime: #{timestamp}",
      priority: :default,
      tags:     ['key']
    )
  end

  def vocabulary_loaded(categories:)
    send(
      title:    '📚 Vocabulary Loaded',
      message:  "Categories: #{categories.join(', ')}\nTime: #{timestamp}",
      priority: :low,
      tags:     ['books']
    )
  end

  def vocabulary_load_failed(reason:)
    send(
      title:    '🚨 Vocabulary Load FAILED',
      message:  "Reason: #{reason}\nTime:   #{timestamp}",
      priority: :high,
      tags:     ['warning', 'rotating_light']
    )
  end

  def reload_triggered(categories:, ip: 'unknown')
    send(
      title:    '🔄 Vocabulary Reloaded',
      message:  "Triggered by: #{ip}\nCategories:   #{categories.join(', ')}\nTime: #{timestamp}",
      priority: :low,
      tags:     ['arrows_counterclockwise']
    )
  end

  def s3_error(operation:, reason:)
    send(
      title:    '☁️  S3 Error',
      message:  "Operation: #{operation}\nReason:    #{reason}\nTime:      #{timestamp}",
      priority: :high,
      tags:     ['warning', 'cloud']
    )
  end

  def spew_generated(topic:, ip: 'unknown')
    send(
      title:    '🔥 Spew Generated',
      message:  "Topic: #{topic}\nIP:    #{ip}\nTime:  #{timestamp}",
      priority: :low,
      tags:     ['fire']
    )
  end

  def app_started
    send(
      title:    '🚀 App Started',
      message:  "BusinessSpew is live\nTime: #{timestamp}",
      priority: :low,
      tags:     ['rocket']
    )
  end

  # Note: this fires on every rejected request — disable if traffic is noisy.
  def invalid_api_key(ip:, path:)
    send(
      title:    '🔑 Invalid API Key',
      message:  "Path: #{path}\nIP:   #{ip}\nTime: #{timestamp}",
      priority: :default,
      tags:     ['key', 'warning']
    )
  end

  def invalid_invite_attempt(code:, reason:, ip:)
    send(
      title:    '🚫 Invalid Invite Attempt',
      message:  "Code:   #{code}\nReason: #{reason}\nIP:     #{ip}\nTime:   #{timestamp}",
      priority: :default,
      tags:     ['no_entry', 'key']
    )
  end

  def reload_degraded(reason:)
    send(
      title:    '⚠️  Reload Degraded',
      message:  "Reason: #{reason}\nTime:   #{timestamp}",
      priority: :high,
      tags:     ['warning']
    )
  end

  def api_key_added(owner:)
    send(
      title:    '➕ API Key Added',
      message:  "Owner: #{owner}\nTime:  #{timestamp}",
      priority: :default,
      tags:     ['key', 'white_check_mark']
    )
  end

  def api_key_disabled(owner:)
    send(
      title:    '🔒 API Key Disabled',
      message:  "Owner: #{owner}\nTime:  #{timestamp}",
      priority: :default,
      tags:     ['key', 'lock']
    )
  end

  def notification_failed(event:, reason:)
    # Best-effort self-notification when another notification fails.
    # Uses a stripped-down request to minimise the chance of a second failure.
    uri = URI(BASE_URL)
    req = Net::HTTP::Post.new(uri)
    req['Title'] = '⚠️  Notification Delivery Failed'
    req.body     = "Event: #{event}\nReason: #{reason}\nTime: #{timestamp}"
    Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |h| h.request(req) }
  rescue StandardError => e
    warn "[Notifier] Meta-notification also failed: #{e.message}"
  end

  private

  def timestamp
    Time.now.strftime('%Y-%m-%d %H:%M:%S %Z')
  end
end
