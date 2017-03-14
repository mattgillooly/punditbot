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
  def self.generate_prediction
    while (prediction ||= nil).nil?
      pundit = Pundit.new
      prediction = pundit.generate_prediction
      puts prediction.to_s
      puts prediction.inspect
      prediction = nil if !prediction.nil? && prediction.column_type == 'integral' && rand < 0.9
    end
    prediction
  end
end
