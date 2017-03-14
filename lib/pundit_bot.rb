require_relative 'utils'
require_relative './pundit_bot/election_history.rb'
require_relative './pundit_bot/pundit.rb'
require_relative './pundit_bot/noun.rb'
require_relative './pundit_bot/data_claim.rb'
require_relative './pundit_bot/dataset.rb'
require_relative './pundit_bot/party.rb'
require_relative './pundit_bot/politics_conditions.rb'
require_relative './pundit_bot/prediction.rb'

module PunditBot
  POLARITIES = [true, false].freeze
  TOO_RECENT_TO_CARE_CUTOFF = 1992 # if the claim is false twice after (including) 1992, then skip the correlation
  MAX_OUTPUT_LENGTH = 140

  def self.generate_prediction
    if true || __FILE__ != $PROGRAM_NAME # if called from a library, do this, unless I set my magic false/true variable to choose what I want to happen
      generate_prediction_simple
    else # counting prediction types, used to figure out some of these weights
      generate_prediction_with_data_claim_counts
    end
  end

  def self.generate_prediction_simple
    while (prediction ||= nil).nil?
      pundit = Pundit.new
      prediction = pundit.generate_prediction
      puts prediction.to_s
      puts prediction.inspect
      prediction = nil if !prediction.nil? && prediction.column_type == 'integral' && rand < 0.9
    end
    prediction
  end

  def self.generate_prediction_with_data_claim_counts
    claim_types = Hash.new(0)
    data_claim_counts = Hash.new(0)
    predictions = []
    loop do
      pundit = Pundit.new
      prediction = pundit.generate_prediction
      next if prediction.nil?
      # 0.80 ==> {:integral=>834, :numeric=>290}
      next if prediction.column_type == :integral && rand < 0.93 # exclude 80% of integral claims
      # available methods: dataset, column, column_type
      next if data_claim_counts[prediction.metadata[:data_claim]] > (data_claim_counts.values.reduce(&:+) || 0) / 5.0
      claim_types[prediction.column_type] += 1
      data_claim_counts[prediction.metadata[:data_claim].inspect.split('merrillj')[-1]] += 1
      predictions << prediction.inspect
      predictions.compact!
      predictions.uniq!
      puts predictions.size
      break if predictions.size >= 10 # was 10
    end
    puts claim_types
    puts data_claim_counts
    puts predictions
  end
end
