require 'simplernlg' if RUBY_PLATFORM == 'java'
puts 'Warning, this only works on JRuby but you can check for syntax errors more quickly in MRE' if RUBY_PLATFORM != 'java'

require_relative './prediction_prover'
require_relative './prediction_sentence_template'
require_relative './rephraser'

module PunditBot
  class Prediction
    attr_accessor :prediction_meta, :prover

    def initialize
      @prediction_meta  = {}
    end

    def build_prediction_text
      sentence_template = PredictionSentenceTemplate.new(@prediction_meta)
      rephrased = Rephraser.build_from_prediction_meta(@prediction_meta).rephrase(sentence_template)
      rephrased.to_s
    end

    def to_s
      @prediction_text ||= build_prediction_text
    end

    def column
      # hurricanes, unemployment, veggies,etc.
      @prediction_meta[:correlate_noun].first.word
    end

    def dataset
      # e.g. integral, whatever
      @prediction_meta[:dataset]
    end

    def column_type
      # e.g. integral, whatever
      @prediction_meta[:data_claim_type]
    end

    def metadata
      {
        column_type: column_type,
        data_claim: @prediction_meta[:data_claim_template].values.map(&:to_s).sort.join(' ')
      }
    end

    def inspect
      @prediction_text
      # [#{dataset}, #{column}, #{column_type}]
      @prediction_text.nil? ? nil : "#{@prediction_text.size} chars: \"#{@prediction_text}\"\n#{prover.prove_it!}\n"
    end

    def self.build(party, correlating_time_series, politics_condition, dataset, politics_claim_truth_vector)
      prediction = Prediction.new

      # used in the actual template
      prediction.prediction_meta[:party] =               party
      prediction.prediction_meta[:claim_polarity] =      correlating_time_series[:polarity]
      prediction.prediction_meta[:start_year] =          correlating_time_series[:start_year]
      prediction.prediction_meta[:data_claim_template] = correlating_time_series[:data_claim].template
      prediction.prediction_meta[:exceptional_year] = correlating_time_series[:exceptional_year]
      prediction.prediction_meta[:politics_condition] =  politics_condition
      prediction.prediction_meta[:correlate_noun] =      correlating_time_series[:correlate_noun]

      prediction.prover = PredictionProver.new(
        correlating_time_series[:covered_years],
        dataset.data,
        correlating_time_series[:data_claim],
        politics_claim_truth_vector
      )

      prediction
    end
  end
end
