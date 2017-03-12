require_relative 'utils'
require_relative './pundit_bot/pundit.rb'
require_relative './pundit_bot/noun.rb'
require_relative './pundit_bot/party.rb'
require_relative './pundit_bot/politics_conditions.rb'
require_relative './pundit_bot/prediction.rb'

module PunditBot
  POLARITIES = [true, false]
  TOO_RECENT_TO_CARE_CUTOFF = 1992 #if the claim is false twice after (including) 1992, then skip the correlation

  #TODO: reorganize code to put settings (like this, data claims, etc.) in one place
  POLITICS_CONDITIONS = {
    :pres_lost => PoliticsCondition.new(
        race: :pres, 
        control: false, # if after the election, the chosen party/person controls the object
        change: false,  # if the election caused a change in control of the object
        objects: [Noun.new("White House", 1), Noun.new("presidency", 1)], # N.B. removed "the" from "the White House" 5/30/2016 to fix https://twitter.com/PunditBot/status/737295983533535232's double the.
        election_interval: 4
    ),
    :sen_lost => PoliticsCondition.new(
        race: :senate, 
        control: false, # if after the election, the chosen party/person controls the object
        change: false,  # if the election caused a change in control of the object
        objects: [Noun.new("Senate", 1)],
        election_interval: 2
    ),
    :house_lost => PoliticsCondition.new(
        race: :house, 
        control: false, # if after the election, the chosen party/person controls the object
        change: false,  # if the election caused a change in control of the object
        objects: [Noun.new("House", 1)],
        election_interval: 2
    ),
    :pres_won => PoliticsCondition.new(
        race: :pres, 
        control: true, # if after the election, the chosen party/person controls the object
        change: false,  # if the election caused a change in control of the object
        objects: [Noun.new("White House", 1), Noun.new("presidency", 1)],
        election_interval: 4
    ),
    :sen_won => PoliticsCondition.new(
        race: :senate, 
        control: true, # if after the election, the chosen party/person controls the object
        change: false,  # if the election caused a change in control of the object
        objects: [Noun.new("Senate", 1)],
        election_interval: 2
    ),
    :house_won => PoliticsCondition.new(
        race: :house, 
        control: true, # if after the election, the chosen party/person controls the object
        change: false,  # if the election caused a change in control of the object
        objects: [Noun.new("House", 1)],
        election_interval: 2
    ),
    # TODO: what, if anything, does 'control' do?
    # and is it working right?


    # TODO: this is broken because so much logic is based on string comparison generating a true/false
    #       without a good way to handle the third case, where one house is controlled by the Democrats
    #       and one by the Republicans. Without a third case, PunditBot assumes that, if the Democrats don't
    #       control both houses of Congress, then the Republicans do. (But in fact, it's split, no one does!)

    # :cong_lost => PoliticsCondition.new(
    #     race: :congress, 
    #     control: false, # if after the election, the chosen party/person controls the object
    #     change: false,  # if the election caused a change in control of the object
    #     objects: [Noun.new("both houses of Congress", 1), Noun.new("House and the Senate", 1), Noun.new("Congress", 1),],
    #     election_interval: 2
    # ),
    # :pres_gain_control => PoliticsCondition.new(
    #     race: :pres, 
    #     control: true, # if after the election, the chosen party/person controls the object
    #     change: true,  # if the election caused a change in control of the object
    #     objects: [Noun.new("White House", 1), Noun.new("presidency", 1)] 
    # ),
    # :pres_lose_control => PoliticsCondition.new(
    #     race: :pres, 
    #     control: false, # if after the election, the chosen party/person controls the object
    #     change: true,  # if the election caused a change in control of the object
    #     objects: [Noun.new("White House", 1), Noun.new("presidency", 1)] 
    # ),
                          # },
                            # "hasn't controlled the Senate" => {},
                            # "hasn't controlled the House" => {},
                            # "has kept or won control of Senate/House" => {},
                            # "has won control of the Senate/House." => {},
                            # "has picked up Senate/House seats" => {},
                            # "has lost Senate/House seats" => {},
                            #TODO: "hasn't won <state>'s electoral votes"
                            #TODO: "hasn't won both of <state>'s Senate seats"
                            #TODO: "hasn't won the White House without <state>",
    }

  MAX_OUTPUT_LENGTH = 140

  def self.generate_prediction
    if true || __FILE__ != $0 # if called from a library, do this, unless I set my magic false/true variable to choose what I want to happen
      until !(prediction ||= nil).nil?
        pundit = Pundit.new
        prediction = pundit.generate_prediction
        puts prediction.to_s
        puts prediction.inspect
        prediction = nil if !prediction.nil? && prediction.column_type == "integral" && rand < 0.9
      end
      return prediction
    else # counting prediction types, used to figure out some of these weights
      claim_types = Hash.new(0)
      data_claim_counts = Hash.new(0)
      predictions = []
      loop do 
        pundit = Pundit.new
        prediction = pundit.generate_prediction
        next if prediction.nil?
                                                                   #0.80 ==> {:integral=>834, :numeric=>290}
        next if prediction.column_type == :integral && rand < 0.93 # exclude 80% of integral claims
        # available methods: dataset, column, column_type
        next if data_claim_counts[prediction.metadata[:data_claim]] > (data_claim_counts.values.reduce(&:+) || 0) / 5.0
        claim_types[prediction.column_type] += 1
        data_claim_counts[prediction.metadata[:data_claim].inspect.split("merrillj")[-1]] += 1
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
end

$settings_for_testing = {
  :dataset  => nil,
                     # unemployment.csv, atlantic_hurricanes.csv, super_bowl.csv, 
                     # vegetables.csv, us_international_trade_in_goods.csv, avg_temperature.csv, 
                     # central_park_election_day_weather.csv, monthly-central-park-snowfall.csv
                     # PCOFFROBUSDA.csv,  GOLDAMGBD228NLBM.csv,  PSOYBUSDQ.csv,  PWHEAMTUSDA.csv,  
                     # PBEEFUSDA.csv,  PIORECRUSDM.csv,  OILPRICE.csv,  HOUSTNSA.csv,  PCECA.csv, 
                     # PSAVERT.csv,  RRVRUSQ156N.csv,  TRFVOLUSM227NFWA.csv, 

  :data_column => nil,
  :politics_condition => nil, # [:sen_lost, :pres_lost, :house_lost, :sen_won, :pres_won, :house_won]
  :political_party => nil,          # [:dem, :gop]
  :data_claim => nil
                    # "greater than", "less than", "is positive", "is negative", 
                    # "grew from the previous year", "declined from the previous year",
                    # "grew year over year", "declined year over year", "increased", "declined",
                    # "grew from the previous election year", "declined from the previous election year",
                    # "was", "adds up to an even number", "adds up to an odd number", 
                    # "starts up to an even number", "starts up to an odd number", "is an even number", 
                    # "is an odd number", 
}
