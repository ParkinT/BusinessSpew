class Spew
  SPACE = " "

  attr_reader :paragraphs, :title, :tweetified, :category

  def initialize(params={})
	defaults = {"paragraphs" => 1, "sentences" => 1, "category" => 'corporate'}
	params = defaults.merge(params)
	@category = params["category"]
	@title ||= params["title"]
	repeat_count = params["paragraphs"].to_i if params["paragraphs"]
	num_sentences = params["sentences"].to_i unless params["sentences"].nil?
	@paragraphs = Array.new
	(1..repeat_count).each do |r|
		sentences = Array.new
		(1..num_sentences).each do
			sentences.push smart_punctuation(generate_sentence)
		end
		@paragraphs.push sentences.join(SPACE * 2)
	end
  end

  def tweet
	sentence_length = 140
	while sentence_length > (140 - "\n#BusinessSpew".length)
		@tweetified = smart_punctuation(generate_sentence)
		sentence_length = tweetified.length
	end
	@tweetified += "\n#BusinessSpew"
  end

private
  def generate_sentence
	@category ||= 'corporate'
	fragments = Array.new
	# although ActivRecord::Base.uncached should permit the use of the SQL 'RANDOM' command, it is thwarted in Postgresql due to aggressive caching

	fragments.push Prefix.where(:category => @category).shuffle.first.segment
	fragments.push Verb.where(:category => @category).shuffle.first.segment
	fragments.push Connector.where(:category => @category).shuffle.first.segment if (rand(12) % 2) #randomize the presence of a connector
	fragments.push Adjective.where(:category => @category).shuffle.first.segment
	fragments.push Noun.where(:category => @category).shuffle.first.segment
	fragments.join(SPACE)
  end

  def smart_punctuation(phrase)
	# It is NOT a mistake that "Where" includes a space.  This is to prevent a false hit on "Whereas" and "Wherein" for the 'Law' category
    	/(Can|Will|When|How|Do you|Do they|Does|Do we|What|Who|Where |Why|Should)/ =~ phrase
	match_data = Regexp.last_match
	phrase + ((match_data) ? "?" : Punctuation.random)
  end

end
