# ~/Sites/BusinessSpew/app.rb
require 'sinatra'
require 'sinatra/reloader' if development?
require 'json'
require 'yaml'

# Load configuration

# Sinatra application
class BusinessSpew < Sinatra::Base
  set :server, 'thin'
  set :port, 9292
  set :bind, '0.0.0.0'
  
  # Root route
  get '/' do
    erb :'index', layout: :'layouts/main'
  end
  
  # API endpoint - example
  get '/api' do
    content_type :json
    
    # Example API response
    {
      name: "Business Spew",
      version: "1.0.0",
      status: "running",
      services: ['/spew', '/api']
    }.to_json
  end
  
  post '/spew' do
    session.show(params)
  end

end

