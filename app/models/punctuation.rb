# NO connection to ActiveRecord - this is independent
class Punctuation

   def self.random
    all.sample
   end

   def self.all
   		[
		".",
		"!",
		".",
		".",
		"!!!",
		".",
		".",
		".",
		".",
		".",
		"!",
		".",
		"."
		]
   end

end
