module PunditBot
  class Rephraser
    MAX_TWEET_LENGTH = 140

    attr_reader :rephraseables, :max_output_length

    def initialize(rephraseables, max_output_length = MAX_TWEET_LENGTH)
      @rephraseables = rephraseables
      @max_output_length = max_output_length
    end

    def self.build_from_prediction_meta(prediction_meta)
      rephrased = {}

      rephrased[:party_noun] = dupnil(prediction_meta[:party].alt_names) # the democrats
      rephrased[:politics_condition_verb] = dupnil(prediction_meta[:politics_condition].verb) # lost
      rephrased[:politics_condition_object] = dupnil(prediction_meta[:politics_condition].objects) # the white house

      data_claim_template = prediction_meta[:data_claim_template]
      if data_claim_template.key?(:o) && data_claim_template[:o] # greater
        rephrased[:data_claim_obj] = (data_claim_template[:o].respond_to?(:min_by) ? data_claim_template[:o] : [data_claim_template[:o]])
      end

      rephrased[:correlate_noun] = dupnil(prediction_meta[:correlate_noun]) # unemployment

      puts "correlate noun: #{dupnil(prediction_meta[:correlate_noun])}"

      rephrased[:since_pp_position] =        [:pre, :post, :front]
      rephrased[:every_year_pp_position] =   [:pre, :post, :front]
      rephrased[:since_after] =              ['since', 'after', 'starting in']
      rephrased[:except] =                   ['except', 'besides', 'except in']
      rephrased[:year_or_election] =         ['year', 'election year']
      rephrased[:when] =                     ['when', 'in years when', 'whenever', 'in years']
      rephrased[:since_pp_modified] =        [:main_clause, :year_pp]

      new(rephrased)
    end

    def rephrase(sentence_template)
      # this is mostly 140-char awareness
      # to do this, we realize the sentence with the shortest option for each "rephraseable" piece of the sentence
      # to find how much extra space we have (and fail if the shortest possible length is > 140).
      # the "margin" -- the extra characters we have to distribute between rephrase options
      #  -- is the difference between the sum of the shortest and sum of the longest rephraseables
      # or the difference between the length of the shortest possible sentence and 140, whichever is less.
      # then, for each rephraseable, we shuffle up all the options and pick one randomly,
      # subtracting the difference between the chosen option and the shortest option from the margin.
      # Reject and re-sample if the margin would go below 0.
      # rephraseable objects like Party are also handled here.
      # which perhaps should implement a Rephraseable mix-in so they can have min_by, max_by

      rephraseables.compact!
      rephraseables.reject! { |_k, v| v.empty? }
      rephrased = {}
      shortest_rephrase_options = {}

      rephraseables.each do |k, v|
        rephrased[k] = shortest_rephrase_options[k] = rephraseables.delete(k) unless v.respond_to?(:min_by)
      end

      min_rephraseable_length = 0
      max_rephraseable_length = 0
      unrephraseable_length = 0
      rephraseables.each do |_k, v|
        if v.respond_to?(:min_by) && !v.empty?
          max_rephraseable_length += v.max_by(&:size).size # +1 for spaces
          min_rephraseable_length += v.min_by(&:size).size # +1 for spaces
        end
      end

      rephraseables.each do |k, v|
        shortest_rephrase_options[k] = v.min_by(&:size)
      end
      puts shortest_rephrase_options.inspect

      shortest_possible_sentence = sentence_template.realize(shortest_rephrase_options)

      if max_output_length < shortest_possible_sentence.size
        puts "way too long (#{shortest_possible_sentence.size}) : #{(shortest_possible_sentence)}"
        return nil
      end

      buffer = max_output_length - shortest_possible_sentence.size 

      rephraseables.to_a.shuffle.each do |k, v|
        # rather than choosing randomly, should prefer longer versions
        # we put each option into the hat once per character in it
        weighted = v.reduce([]) { |memo, nxt| memo += [nxt] * nxt.size }
        weighted.shuffle!
        chosen_word = weighted.first
        redo if buffer - (chosen_word.size - weighted.min_by(&:size).size) < 0
        rephrased[k] = chosen_word
        puts "chosen word: #{chosen_word}"
        buffer -= (chosen_word.size - weighted.min_by(&:size).size)
      end

      puts "rephrased.inspect: #{rephrased.inspect}"
      sentence_template.realize(rephrased)
    end

    private

    def self.dupnil(obj)
      obj.nil? ? nil : obj.dup
    end
  end
end
