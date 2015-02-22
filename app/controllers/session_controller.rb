require 'spew'

class SessionController < ApplicationController
  SPACE = " "
  def index
	@tweet =  Spew.new({"paragraphs" => 1, "sentences" => 3}).tweet
  end

  def show
	@spew = Spew.new(params)  #Spew new is fun to say!
	render :show
  end

end
