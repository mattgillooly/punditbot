module PunditBot
  class PoliticsCondition
    attr_reader :race, :jurisdiction, :objects, :change, :control, :election_interval
    def initialize(obj)
      @race = obj[:race]
      @control = obj[:control]
      @change = obj[:change]
      @objects = obj[:objects].respond_to?(:sample) ? obj[:objects] : [obj[:objects]]
      @jurisdiction = obj[:jurisdiction] || 'USA'
      @election_interval = obj[:election_interval]
    end

    def verb
      @change ? (@control ? 'taken' : 'give up') : (@control ? 'win' : 'lose')
    end

    def satisfied?(actual_control, control_changed)
      if change
        (control == actual_control) && control_changed
      else
        control == actual_control
      end
    end
  end

  POLITICS_CONDITIONS = {
    pres_lost: PoliticsCondition.new(
      race: :pres,
      control: false, # if after the election, the chosen party/person controls the object
      change: false,  # if the election caused a change in control of the object
      objects: [Noun.new('White House', 1), Noun.new('presidency', 1)],
      election_interval: 4
    ),
    sen_lost: PoliticsCondition.new(
      race: :senate,
      control: false, # if after the election, the chosen party/person controls the object
      change: false,  # if the election caused a change in control of the object
      objects: [Noun.new('Senate', 1)],
      election_interval: 2
    ),
    house_lost: PoliticsCondition.new(
      race: :house,
      control: false, # if after the election, the chosen party/person controls the object
      change: false,  # if the election caused a change in control of the object
      objects: [Noun.new('House', 1)],
      election_interval: 2
    ),
    pres_won: PoliticsCondition.new(
      race: :pres,
      control: true, # if after the election, the chosen party/person controls the object
      change: false, # if the election caused a change in control of the object
      objects: [Noun.new('White House', 1), Noun.new('presidency', 1)],
      election_interval: 4
    ),
    sen_won: PoliticsCondition.new(
      race: :senate,
      control: true, # if after the election, the chosen party/person controls the object
      change: false, # if the election caused a change in control of the object
      objects: [Noun.new('Senate', 1)],
      election_interval: 2
    ),
    house_won: PoliticsCondition.new(
      race: :house,
      control: true, # if after the election, the chosen party/person controls the object
      change: false, # if the election caused a change in control of the object
      objects: [Noun.new('House', 1)],
      election_interval: 2
    ),
  }.freeze
end
