require 'spew'
class ApiController < ApplicationController

  layout false
  
  def index #show instructions
	  # static page
    
  end

  def show
    @json_spew = ActiveSupport::JSON.encode(Spew.new({"title" => params['title'], "sentences" => params['sentences'], "paragraphs" => params['paragraphs']}))
  end

end
