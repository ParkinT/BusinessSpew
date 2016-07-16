require 'spew'
class ApiController < ApplicationController

  layout false

  def index #show instructions
	  # static page

  end

  def show
    render :json => Spew.new({'title' => params.fetch('title', ""), 'sentences' => params.fetch('sentences', "1"), 'paragraphs' => params.fetch('paragraphs', "1")})
  end

end
