class Lexicon < ActiveRecord::Base

   def initialize
   		prefix = Prefix.first(:order => "RAND()")
   		@sentence = "#{prefix}"
   end

   def prefix=(phrase)
   	segment = Prefix.new(phrase)
   	segment.save!
   end
end
