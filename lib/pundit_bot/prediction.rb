require 'simplernlg' if RUBY_PLATFORM == 'java'
puts 'Warning, this only works on JRuby but you can check for syntax errors more quickly in MRE' if RUBY_PLATFORM != 'java'

require_relative './prediction_sentence_template'
require_relative './rephraser'

module PunditBot
  class Prediction
    attr_accessor :prediction_meta, :prediction_debug

    def initialize
      @prediction_meta  = {}
      @prediction_debug = {}
    end

    def build_prediction_text
      sentence_template = PredictionSentenceTemplate.new(@prediction_meta)
      rephrased = Rephraser.build_from_prediction_meta(@prediction_meta).rephrase(sentence_template)
      rephrased.to_s
    end

    def to_s
      @prediction_text ||= build_prediction_text
    end

    def prove_it!
      ''" e.g.
      2012  2008  2004  2000  1996  1992  1988
      7.8   8.2   7.9   8.1   etc   etc   etc
      true  true  false false true  true  false
      "''
      years = @prediction_debug[:covered_years]
      data = years.map { |yr| @prediction_debug[:data][yr] }
      max_data_length = [data.map { |d| d.to_s.size }.max, 4].max # max length in chars of each of the numbers from the dataset
      data_truth = data.zip(years).map do |datum, yr|
        begin
          @prediction_debug[:data_claim].condition.call(datum, yr)
        rescue ArgumentError
          nil
        end
      end
      victor = years.map { |yr| @prediction_debug[:politics_claim_truth_vector][yr] }

      pad = ->(x) { (x.to_s + '    ')[0...max_data_length] }

      [years, data, data_truth, victor].map { |row| row.map(&pad).join("\t") }.join("\n")
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
      @prediction_text.nil? ? nil : "#{@prediction_text.size} chars: \"#{@prediction_text}\"\n#{prove_it!}\n"
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

      # used for debug
      prediction.prediction_debug[:covered_years] =               correlating_time_series[:covered_years]
      prediction.prediction_debug[:data] =                        dataset.data
      prediction.prediction_debug[:data_claim] =                  correlating_time_series[:data_claim] # DataClaim objcet
      prediction.prediction_debug[:politics_claim_truth_vector] = politics_claim_truth_vector
      # prediction.prediction_debug[:end_year] =                    @dataset.max_year )
      # prediction.prediction_debug[:data_claim_type] =             correlating_time_series[:data_claim_type])
      # prediction.prediction_debug[:election_interval] =           politics_condition.election_interval)

      prediction
    end
  end # ends the class
end # ends the module
