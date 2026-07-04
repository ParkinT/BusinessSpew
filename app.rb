# app.rb
require 'sinatra/base'
require 'json'
require_relative 'lib/constants'
require_relative 'lib/spew_generator'
require_relative 'lib/auth_store'
require_relative 'lib/notifier'
require_relative 'lib/invite_code_validator'

module BusinessSpew
  class App < Sinatra::Base

    INVITE_COOKIE     = 'bs_access'.freeze
    INVITE_COOKIE_TTL = 60 * 60 * 24 * 30  # 30 days
    FREE_VISIT_COOKIE = 'bs_free_visit'.freeze  # session-only, no expiry

    # ── Startup ───────────────────────────────────────────────────────
    configure do
      begin
        BusinessSpew::SpewGenerator.vocabulary
        Notifier.vocabulary_loaded(categories: SpewGenerator.categories)
      rescue StandardError => e
        Notifier.vocabulary_load_failed(reason: e.message)
        warn "WARNING: vocabulary failed to load at startup: #{e.message}"
      end

      begin
        set :auth_store, BusinessSpew::AuthStore.new
      rescue StandardError => e
        Notifier.s3_error(operation: 'AuthStore initialisation', reason: e.message)
        warn "WARNING: AuthStore failed to initialise: #{e.message}"
      end
    end

    # ── Error handlers ────────────────────────────────────────────────
    error SpewGenerator::VocabularyUnavailableError do
      content_type :json
      status 503
      { error: 'Vocabulary service unavailable. Try again shortly.' }.to_json
    end

    # ── Auth helpers ──────────────────────────────────────────────────
    helpers do
      def app_version
        BusinessSpew::VERSION
      end

      def auth_store
        settings.auth_store
      end

      def require_api_key!
        key = request.env['HTTP_X_API_KEY']
        unless auth_store.valid_key?(key)
          halt 401, { 'Content-Type' => 'application/json' },
               { error:   'Unauthorised. A valid API key is required.',
                 contact: 'Visit https://leveragedsynergies.com to request access.' }.to_json
        end
      end

      def playground_access?
        request.cookies[INVITE_COOKIE] == 'granted'
      end

      def free_visit_access?
        request.cookies[FREE_VISIT_COOKIE] == 'true'
      end

      def spew_access?
        api_key = request.env['HTTP_X_API_KEY']
        auth_store.valid_key?(api_key) || playground_access? || free_visit_access?
      end

      def client_ip
        request.env['HTTP_X_FORWARDED_FOR']&.split(',')&.first&.strip ||
          request.ip
      end

      def render_spew(topic:, sentences: nil, paragraphs: nil, title: nil)
        sentence_count  = (sentences  && !sentences.to_s.empty?)  ? sentences.to_i  : 3
        paragraph_count = (paragraphs && !paragraphs.to_s.empty?) ? paragraphs.to_i : 1

        result = SpewGenerator.spew(
          paragraph_count: paragraph_count,
          sentence_count:  sentence_count,
          category:        topic
        )

        resolved_title = title.to_s.strip.empty? \
          ? SpewGenerator.default_title(category: topic) \
          : title

        {
          title:      resolved_title,
          topic:      topic,
          paragraphs: result
        }.to_json
      end
    end

    # ── Playground routes (no API key required) ───────────────────────
    get '/' do
      if request.host.start_with?('bs.')
        @categories = SpewGenerator.vocabulary_loaded? ? SpewGenerator.categories : []
        @has_access = playground_access?
        erb :playground, layout: false
      else
        erb :landing, layout: false
      end
    end

    get '/api-docs' do
      erb :api_docs, layout: false
    end

    get '/api-access' do
      erb :api_access, layout: false
    end

    # Validate an invite code and set a 30-day access cookie
    post '/validate-invite' do
      content_type :json
      body        = request.body.read
      params_in   = body.empty? ? {} : JSON.parse(body)
      code        = params_in['code'].to_s.strip

      unless InviteCodeValidator.valid?(code)
        reason = InviteCodeValidator.failure_reason(code)
        halt 403, { error: 'Invalid invite code.', reason: reason }.to_json
      end

      # Set persistent cookie
      response.set_cookie(
        INVITE_COOKIE,
        value:    'granted',
        expires:  Time.now + INVITE_COOKIE_TTL,
        path:     '/',
        httponly: true,
        secure:   true,
        same_site: :lax
      )

      Notifier.invite_redeemed(code: code, ip: client_ip)

      { status: 'ok', message: 'Access granted.' }.to_json
    end

    # Grant a session-only free visit — cookie expires when browser closes
    post '/free-visit' do
      content_type :json
      response.set_cookie(
        FREE_VISIT_COOKIE,
        value:    'true',
        path:     '/',
        httponly: true,
        secure:   true,
        same_site: :lax
        # No :expires — session cookie, gone when browser closes
      )
      { status: 'ok' }.to_json
    end

    # ── API routes (API key required) ─────────────────────────────────
    before '/api*' do
      next if request.path == '/api'        # status endpoint is public
      next if request.path == '/api-docs'   # docs page is public
      next if request.path == '/api-access' # access info page is public
      require_api_key!
    end

    before '/spew' do
      unless spew_access?
        halt 401, { 'Content-Type' => 'application/json' },
             { error:   'Unauthorised. A valid API key is required.',
               contact: 'Visit https://leveragedsynergies.com to request access.' }.to_json
      end
    end

    get '/api' do
      content_type :json
      {
        name:       'Business Spew',
        version:    BusinessSpew::VERSION,
        status:     SpewGenerator.vocabulary_loaded? ? 'running' : 'degraded (vocabulary unavailable)',
        categories: SpewGenerator.vocabulary_loaded? ? SpewGenerator.categories : [],
        services:   ['/spew', '/api']
      }.to_json
    end

    post '/spew' do
      content_type :json
      body      = request.body.read
      params_in = body.empty? ? {} : JSON.parse(body)
      category  = params_in['topic'] || params_in['category']

      result = SpewGenerator.spew(
        paragraph_count: (params_in['paragraphs'] || 1).to_i,
        sentence_count:  (params_in['sentences']  || 3).to_i,
        category:        category
      )

      resolved_title = params_in['title'].to_s.strip.empty? \
        ? SpewGenerator.default_title(category: category) \
        : params_in['title']

      if auth_store.notify_on_spew?
        Notifier.spew_generated(topic: category || 'random', ip: client_ip)
      end

      {
        title:      resolved_title,
        topic:      category || SpewGenerator.categories.sample,
        paragraphs: result
      }.to_json
    end

    get '/api/:topic/*' do
      content_type :json
      topic = params[:topic]
      tail  = params[:splat].first.to_s.split('/')
      sentences, paragraphs, title = tail[0], tail[1], tail[2]

      unless SpewGenerator.vocabulary_loaded? && SpewGenerator.categories.include?(topic)
        halt 404, {
          error:            "Unknown topic '#{topic}'",
          available_topics: SpewGenerator.vocabulary_loaded? ? SpewGenerator.categories : []
        }.to_json
      end

      if auth_store.notify_on_spew?
        Notifier.spew_generated(topic: topic, ip: client_ip)
      end

      render_spew(topic: topic, sentences: sentences, paragraphs: paragraphs, title: title)
    end

    get '/api/:topic' do
      content_type :json
      topic = params[:topic]

      unless SpewGenerator.vocabulary_loaded? && SpewGenerator.categories.include?(topic)
        halt 404, {
          error:            "Unknown topic '#{topic}'",
          available_topics: SpewGenerator.vocabulary_loaded? ? SpewGenerator.categories : []
        }.to_json
      end

      if auth_store.notify_on_spew?
        Notifier.spew_generated(topic: topic, ip: client_ip)
      end

      render_spew(topic: topic)
    end

    get '/api/*' do
      content_type :json
      tail          = params[:splat].first.to_s.split('/')
      sentences, paragraphs, title = tail[0], tail[1], tail[2]
      random_topic  = SpewGenerator.vocabulary_loaded? ? SpewGenerator.categories.sample : nil

      if auth_store.notify_on_spew?
        Notifier.spew_generated(topic: random_topic || 'random', ip: client_ip)
      end

      render_spew(topic: random_topic, sentences: sentences, paragraphs: paragraphs, title: title)
    end

    # ── Utility routes ────────────────────────────────────────────────
    get '/health' do
      content_type :json
      if SpewGenerator.vocabulary_loaded?
        { status: 'ok' }.to_json
      else
        status 503
        { status: 'degraded', reason: 'vocabulary not loaded' }.to_json
      end
    end

    get '/favicon.ico' do
      content_type 'image/svg+xml'
      headers 'Cache-Control' => 'public, max-age=86400'
      <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
          <text y="28" font-size="28">🔥</text>
        </svg>
      SVG
    end

    get '/robots.txt' do
      content_type 'text/plain'
      headers 'Cache-Control' => 'public, max-age=86400'
      <<~ROBOTS
        User-agent: *
        Allow: /
        Disallow: /admin/
        Disallow: /health
        Disallow: /validate-invite

        Sitemap: https://leveragedsynergies.com/sitemap.xml
      ROBOTS
    end

    # ── Admin routes ──────────────────────────────────────────────────
    # TODO: add authentication before this is publicly reachable.
    post '/admin/reload' do
      content_type :json
      begin
        SpewGenerator.reload!
        auth_store.reload!

        if SpewGenerator.vocabulary_loaded?
          Notifier.reload_triggered(
            categories: SpewGenerator.categories,
            ip:         client_ip
          )
          { status: 'ok', categories: SpewGenerator.categories }.to_json
        else
          status 503
          { status: 'degraded', reason: 'reload ran but vocabulary still empty' }.to_json
        end
      rescue StandardError => e
        Notifier.s3_error(operation: 'admin reload', reason: e.message)
        status 502
        { status: 'error', reason: e.message }.to_json
      end
    end

  end
end
