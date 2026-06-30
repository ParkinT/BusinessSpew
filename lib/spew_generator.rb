# lib/spew_generator.rb
require_relative 's3_data_store'

module BusinessSpew
  module SpewGenerator
    extend self

    class VocabularyUnavailableError < StandardError; end

    # Lazily load and cache vocabulary from S3 (all categories merged)
    def vocabulary
      @vocabulary ||= load_vocabulary
    end

    # Force a re-fetch from S3 (e.g. via an admin route, or on a schedule)
    def reload!
      @vocabulary = load_vocabulary
    end

    def vocabulary_loaded?
      !vocabulary.nil? && !vocabulary.empty?
    end

    # Generate a single sentence, optionally scoped to one category (e.g. "tech")
    def sentence(category: nil)
      raise VocabularyUnavailableError, "Vocabulary failed to load from S3" unless vocabulary_loaded?

      pool = vocab_pool(category)
      prefix    = pool['prefixes'].sample
      verb      = pool['verbs'].sample
      noun      = pool['nouns'].sample
      result    = "#{prefix} #{verb} #{noun}"

      # 50/50 chance to extend with a connector clause for variety
      if rand < 0.5
        connector = pool['connectors'].sample
        verb2     = pool['verbs'].sample
        noun2     = pool['nouns'].sample
        result += ", #{connector} #{verb2} #{noun2}"
      end

      "#{result}."
    end

    # Generate multiple sentences as a paragraph
    def paragraph(sentence_count: 3, category: nil)
      Array.new(sentence_count) { sentence(category: category) }.join(' ')
    end

    # Generate multiple paragraphs
    def spew(paragraph_count: 1, sentence_count: 3, category: nil)
      Array.new(paragraph_count) {
        paragraph(sentence_count: sentence_count, category: category)
      }
    end

    def categories
      vocabulary.keys
    end

    TITLE_TEMPLATES = [
      "%{noun} Initiative",
      "%{noun} Strategy Brief",
      "%{noun} Alignment Memo",
      "The %{noun} Roadmap",
      "%{noun} Synergy Report",
      "Operational %{noun} Review",
      "%{noun} Action Plan"
    ].freeze

    # Builds a default, on-brand corporate-jargon title when none is
    # supplied by the caller. Pulls a noun from the relevant category's
    # vocabulary (or the merged pool, for a random/no-topic request) and
    # drops it into a randomly selected template.
    def default_title(category: nil)
      return "Business Spew" unless vocabulary_loaded?

      pool = vocab_pool(category)
      noun = pool['nouns'].sample&.split(' ')&.map(&:capitalize)&.join(' ') || 'Business'
      template = TITLE_TEMPLATES.sample
      template % { noun: noun }
    end

    private

    def load_vocabulary
      store = S3DataStore.new
      data = store.fetch_all_vocabulary
      data.empty? ? nil : data
    end

    # Returns the vocabulary pool for a given category, or a merged pool
    # of all categories if none is specified / found.
    def vocab_pool(category)
      return nil if vocabulary.nil? || vocabulary.empty?

      if category && vocabulary.key?(category)
        vocabulary[category]
      else
        merge_all_categories
      end
    end

    def merge_all_categories
      vocabulary.values.each_with_object({
        'nouns' => [], 'verbs' => [], 'connectors' => [], 'prefixes' => []
      }) do |cat_data, merged|
        merged['nouns']      += cat_data['nouns']
        merged['verbs']      += cat_data['verbs']
        merged['connectors'] += cat_data['connectors']
        merged['prefixes']   += cat_data['prefixes']
      end
    end
  end
end

if __FILE__ == $0
  puts "Categories available: #{BusinessSpew::SpewGenerator.categories.join(', ')}"
  puts "\nSingle sentence:"
  puts BusinessSpew::SpewGenerator.sentence

  puts "\nTech-only sentence:"
  puts BusinessSpew::SpewGenerator.sentence(category: 'tech')

  puts "\nParagraph (3 sentences):"
  puts BusinessSpew::SpewGenerator.paragraph(sentence_count: 3)
end
