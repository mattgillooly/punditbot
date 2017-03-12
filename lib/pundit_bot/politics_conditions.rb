module PunditBot
  class PoliticsCondition
    # was politics_verb_phrase
    attr_reader :race, :jurisdiction, :objects, :change, :control, :election_interval 
    def initialize(obj)
      @race = obj[:race]
      @control = obj[:control]
      @change = obj[:change]
      @objects = obj[:objects].respond_to?( :sample) ? obj[:objects] : [obj[:objects]]
      @jurisdiction = obj[:jurisdiction] || "USA"
      @election_interval  = obj[:election_interval]
    end
    def verb
      # TODO: support other verbs, e.g. pick up seats
      @change ? (@control ? 'taken' : 'give up') : (@control ? 'win' : 'lose')
    end
  end

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
end
