require 'sinatra/base'
require 'json'
require_relative 'lib/spew_generator'

module BusinessSpew
  class App < Sinatra::Base

    # Eagerly load vocabulary once at startup so requests don't hit S3 every time.
    # If S3 is unreachable, the app still boots — individual routes will
    # report the failure via the error handler below, and #reload! can
    # recover without a restart once S3 is reachable again.
    configure do
      begin
        BusinessSpew::SpewGenerator.vocabulary
      rescue StandardError => e
        warn "WARNING: vocabulary failed to load at startup: #{e.message}"
      end
    end

    error SpewGenerator::VocabularyUnavailableError do
      content_type :json
      status 503
      { error: "Vocabulary service unavailable. Try again shortly." }.to_json
    end

    helpers do
      def render_spew(topic:, sentences: nil, paragraphs: nil, title: nil)
        sentence_count  = (sentences  && !sentences.to_s.empty?)  ? sentences.to_i  : 3
        paragraph_count = (paragraphs && !paragraphs.to_s.empty?) ? paragraphs.to_i : 1

        result = SpewGenerator.spew(
          paragraph_count: paragraph_count,
          sentence_count:  sentence_count,
          category:        topic
        )

        {
          title: title,
          topic: topic,
          paragraphs: result
        }.to_json
      end
    end

    get '/' do
      "Business Spew API - Ready!"
    end

    get '/api' do
      content_type :json
      {
        name: "Business Spew",
        version: "1.0.0",
        status: SpewGenerator.vocabulary_loaded? ? "running" : "degraded (vocabulary unavailable)",
        categories: SpewGenerator.vocabulary_loaded? ? SpewGenerator.categories : [],
        services: ['/spew', '/api']
      }.to_json
    end

    post '/spew' do
      content_type :json
      body = request.body.read
      params_in = body.empty? ? {} : JSON.parse(body)

      result = SpewGenerator.spew(
        paragraph_count: (params_in['paragraphs'] || 1).to_i,
        sentence_count:  (params_in['sentences']  || 3).to_i,
        category:        params_in['category']
      )

      { paragraphs: result }.to_json
    end

    # GET /api/:topic[/sentences[/paragraphs[/title]]]
    # Uses a splat instead of chained optional params (e.g. :sentences?)
    # because Sinatra's optional-segment regex does not reliably match
    # partial combinations (confirmed: /api/tech/2/4 matched but
    # /api/tech/2 alone 404'd). Splatting the tail and parsing manually
    # sidesteps that regex behavior entirely.
    get '/api/:topic/*' do
      content_type :json

      topic = params[:topic]
      tail  = params[:splat].first.to_s.split('/')
      sentences, paragraphs, title = tail[0], tail[1], tail[2]

      unless SpewGenerator.vocabulary_loaded? && SpewGenerator.categories.include?(topic)
        status 404
        halt({
          error: "Unknown topic '#{topic}'",
          available_topics: SpewGenerator.vocabulary_loaded? ? SpewGenerator.categories : []
        }.to_json)
      end

      render_spew(topic: topic, sentences: sentences, paragraphs: paragraphs, title: SpewGenerator.default_title)
    end

    # GET /api/:topic  (no trailing segments at all)
    get '/api/:topic' do
      content_type :json
      topic = params[:topic]

      unless SpewGenerator.vocabulary_loaded? && SpewGenerator.categories.include?(topic)
        status 404
        halt({
          error: "Unknown topic '#{topic}'",
          available_topics: SpewGenerator.vocabulary_loaded? ? SpewGenerator.categories : []
        }.to_json)
      end

      render_spew(topic: topic)
    end

    # GET /api/sentences[/paragraphs[/title]]  (no topic — chosen at random)
    get '/api/*' do
      content_type :json
      tail = params[:splat].first.to_s.split('/')
      sentences, paragraphs, title = tail[0], tail[1], tail[2]
      random_topic = SpewGenerator.vocabulary_loaded? ? SpewGenerator.categories.sample : nil
      render_spew(topic: random_topic, sentences: sentences, paragraphs: paragraphs, title: title)
    end

    # Lightweight health check — useful for load balancers / uptime monitors
    get '/health' do
      content_type :json
      if SpewGenerator.vocabulary_loaded?
        { status: 'ok' }.to_json
      else
        status 503
        { status: 'degraded', reason: 'vocabulary not loaded' }.to_json
      end
    end

    # ------------------------------------------------------------------
    # ADMIN ROUTE — TODO: add authentication before this is publicly
    # reachable (API key header, Basic Auth, etc). Currently open.
    # ------------------------------------------------------------------
    post '/admin/reload' do
      content_type :json
      begin
        SpewGenerator.reload!
        if SpewGenerator.vocabulary_loaded?
          { status: 'ok', categories: SpewGenerator.categories }.to_json
        else
          status 503
          { status: 'degraded', reason: 'reload ran but vocabulary still empty' }.to_json
        end
      rescue StandardError => e
        status 502
        { status: 'error', reason: e.message }.to_json
      end
    end

  end
end
