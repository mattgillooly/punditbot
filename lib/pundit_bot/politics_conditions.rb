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
end
