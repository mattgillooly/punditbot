require 'csv'

module PunditBot
  class Party
    # TODO: formalize the relationship between the third alt-name ("Democrats") and the member_name ("Democrat")
    attr_reader :name, :alt_names, :wikipedia_symbol, :member_name

    def initialize(name, alt_names, wikipedia_symbol,  member_name)
      @name = name.first
      @alt_names = ([name] + alt_names).map { |name, num| Noun.new(name, num) }
      @wikipedia_symbol = wikipedia_symbol
      @member_name = member_name
    end

    def allow_singular!
      @alt_names << Noun.new("a #{@member_name}", 1)
    end

    def rephrase
      @name = @alt_names.sample
      self
    end

    def max_by(&blk)
      @alt_names.max_by(&blk)
    end

    def min_by(&blk)
      @alt_names.min_by(&blk)
    end
  end

  PARTIES = {
    dem: Party.new(['the Democratic Party', 1], [['the Dems', 2], ['the Democrats', 2]], 'D', 'Democrat'),
    gop: Party.new(['the Republican Party', 1], [['the G.O.P.', 1], ['the Republicans', 2]], 'R', 'Republican')
  }.freeze
end
