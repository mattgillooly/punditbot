require 'simplernlg' if RUBY_PLATFORM == 'java'
puts 'Warning, this only works on JRuby but you can check for syntax errors more quickly in MRE' if RUBY_PLATFORM != 'java'

module PunditBot
  class PredictionSentenceTemplate
    attr_accessor :prediction_meta

    def initialize(prediction_meta)
      @prediction_meta = prediction_meta
    end

    def build_sentence_hash(rephrased)
      # should pull only from @prediction_meta and rephrased
      # I don't think we ever will need to vary anything from @prediction_meta
      puts "s: #{@prediction_meta[:data_claim_template][:n].nil? ? rephrased[:correlate_noun] : @prediction_meta[:data_claim_template][:n].call(rephrased[:correlate_noun])}"

      sentence_hash = {
        s: rephrased[:party_noun].word,
        number: rephrased[:party_noun].number, # 1 or 2, depending on grammatical number of rephrased[:party_noun]
        v: rephrased[:politics_condition_verb],
        perfect: true,
        tense: :present,
        o: { det: 'the',
             noun: rephrased[:politics_condition_object].word },
        negation: !@prediction_meta[:claim_polarity],
        prepositional_phrases: [ # these should be randomly assigned as modifiers
          {
            preposition: 'in',
            rest: {
              determiner: @prediction_meta[:claim_polarity] ? 'every' : 'any',
              noun: rephrased[:year_or_election],
              complements: [{
                complementizer: rephrased[:when], # NLG::Feature::COMPLEMENTISER, 'when' # requires 3eed77f5bf6ce0e2655d80ce3ba453696ad5bb8a in my fork of SimpleNLG
              }
                .merge(@prediction_meta[:data_claim_template])
                .merge(s: @prediction_meta[:data_claim_template][:n].nil? ? rephrased[:correlate_noun].word : @prediction_meta[:data_claim_template][:n].call(rephrased[:correlate_noun]))]
            },
            appositive: true,
            position: rephrased[:every_year_pp_position]
          }
        ]
      }

      since_pp = {
        # TODO: this should optionally also be allowed to attach to the "in every year" PP that's right below.
        preposition: rephrased[:since_after],
        rest: @prediction_meta[:start_year],
        appositive: true, # maybe this should just check for whether it's a word or more than one word
        position: rephrased[:since_pp_position]
      }

      if rephrased[:since_pp_modified] == :main_clause || rephrased[:since_pp_position] == :front # for now, we can't allow this to be a frontmodifier if it's modifying the year_pp
        puts 'since_pp_modified is main_clause'
        sentence_hash[:prepositional_phrases] << since_pp
      elsif rephrased[:since_pp_modified] == :year_pp
        puts 'since_pp_modified is year_pp' # tROUBLE
        sentence_hash[:prepositional_phrases].find { |pp| pp[:rest][:noun] == rephrased[:year_or_election] }[:prepositional_phrases] = [since_pp]
      else
        raise ArgumentError, "couldn't figure out where to put the since_pp"
      end

      if @prediction_meta[:exceptional_year]
        sentence_hash[:prepositional_phrases] << {
          preposition: rephrased[:except],
          rest: @prediction_meta[:exceptional_year],
          appositive: true,
          position: :post
        }
      end

      sentence_hash
    end

    def realize(rephrased)
      sentence_hash = build_sentence_hash(rephrased)
      SimplerNLG::NLG.render(sentence_hash)
    end
  end
end
