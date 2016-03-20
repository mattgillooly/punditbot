require 'csv'
require 'yaml'

require 'simplernlg' if RUBY_PLATFORM == 'java'
puts "Warning, this only works on JRuby but you can check for syntax errors more quickly in MRE" if RUBY_PLATFORM != 'java'
NLG = SimplerNLG::NLG

$settings_for_testing = {
  :dataset  => nil,  
                     # unemployment.csv, atlantic_hurricanes.csv, super_bowl.csv, 
                     # vegetables.csv, us_international_trade_in_goods.csv, avg_temperature.csv, 
                     # central_park_election_day_weather.csv, monthly-central-park-snowfall.csv
  :data_column => nil,
  :politics_condition => nil, # [:sen_lost, :pres_lost, :house_lost]
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


module PunditBot
  POLARITIES = [true, false]
  TOO_RECENT_TO_CARE_CUTOFF = 1992 #if the claim is false twice after (including) 1992, then skip the correlation

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

  class Noun #< String
    attr_reader :word
    def initialize(word, number)
      @word = word.is_a?(Noun) ? word.word : word
      @number = number
    end

    def number
      plural? ? :plural : :singular
    end

    def plural?
      @number != 1
    end

    def singular?
      @number == 1
    end

    # if this inherits from String, get rid of #to_s and #size
    def to_s
      "Noun: #{@word}"
    end

    def size
      word.size
    end
  end

  #TODO: reorganize code to put settings (like this, data claims, etc.) in one place
  POLITICS_CONDITIONS = {
    :pres_lost => PoliticsCondition.new(
        race: :pres, 
        control: false, # if after the election, the chosen party/person controls the object
        change: false,  # if the election caused a change in control of the object
        objects: [Noun.new("the White House", 1), Noun.new("the presidency", 1)],
        election_interval: 4
    ),
    :sen_lost => PoliticsCondition.new(
        race: :senate, 
        control: false, # if after the election, the chosen party/person controls the object
        change: false,  # if the election caused a change in control of the object
        objects: [Noun.new("the Senate", 1)],
        election_interval: 2
    ),
    :house_lost => PoliticsCondition.new(
        race: :house, 
        control: false, # if after the election, the chosen party/person controls the object
        change: false,  # if the election caused a change in control of the object
        objects: [Noun.new("the House", 1)],
        election_interval: 2
    ),
    # TODO: what, if anything, does 'control' do?
    # and is it working rihgt?


    # TODO: this is broken because so much logic based on comparing strings
    # but, the "Split" condition is a problem here
    # it's not the case that if the Democrats control one house (i.e. "Split")
    # that the Democrats have lost both houses
    # :cong_lost => PoliticsCondition.new(
    #     race: :congress, 
    #     control: false, # if after the election, the chosen party/person controls the object
    #     change: false,  # if the election caused a change in control of the object
    #     objects: [Noun.new("both houses of Congress", 1), Noun.new("the House and the Senate", 1), Noun.new("Congress", 1),],
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

  class Party

    # TODO: formalize the relationship between the third alt-name ("Democrats") and the member_name ("Democrat")
    attr_reader :name, :alt_names, :wikipedia_symbol, :member_name
    def initialize(name, alt_names, wikipedia_symbol,  member_name)
      @name = name.first
      @alt_names = ([name] + alt_names).map{|name, num| Noun.new(name, num) }
      @wikipedia_symbol = wikipedia_symbol
      @member_name = member_name
    end

    def rephrase
      @name = @alt_names.sample
      self
    end
    def max_by &blk
      @alt_names.max_by(&blk)
    end
    def min_by &blk
      @alt_names.min_by(&blk)
    end
  end
  PARTIES = {
    :dem => Party.new(["Democratic Party", 1], [["Dems", 2], ["Democrats", 2]], 'D', "Democrat"), 
    :gop => Party.new(["Republican Party", 1], [["G.O.P.", 1], ["Republicans", 2]], 'R', "Republican")
  }

  class DataClaim
    attr_reader :condition, :year_buffer, :name
    attr_accessor :template
    def initialize(condition, template, name, year_buffer = nil)
      @template = template
      @name = name
      raise ArgumentError, "DataClaim condition is not callable" unless condition.respond_to? :call
      @condition = condition
      @year_buffer = year_buffer || 0
    end

    # refactor: move this into realize_sentence.rb
    def phrase(complement_subject_noun)
      if !@template[:n].nil?
        complement_subject = @template[:n].call(complement_subject_noun)
      else
        complement_subject = NLG.factory.create_noun_phrase(complement_subject_noun.word)
        complement_subject.set_feature NLG::Feature::NUMBER, complement_subject_noun.singular? ? NLG::NumberAgreement::SINGULAR : NLG::NumberAgreement::PLURAL
      end
      NLG.phrase(@template.merge({
          :s => complement_subject,
      }))
    end
  end


  class Dataset
    attr_reader :name, :nouns, :min_year, :max_year, :data, :source, :data_type
    def initialize(obj) 
      # create a dataset object from it
      # Notably: only one dataset object per spreadsheet
      # - this means a column from a dataset with one column is more likely to be used than a 
      #   column from a dataset with many; this is intentional. We're randomly choosing datasets (for now).

      # read in CSV, process (e.g. numerics get gsubbed out non numeric chars.)
      # keep year column as string
      @name = obj["filename"]
      @csv = CSV.read("data/correlates/#{obj["filename"]}", {:headers => true})
      @year_column_header = obj["year_column_header"]
      sorted_years = @csv.map{|row| row[@year_column_header].match(/\d{4}/)[0] }.sort
      @min_year = sorted_years.first
      @max_year = sorted_years.last
      @data_columns = obj["data_columns"]
      @source = obj["source"]
    end

    def cleaners
      { 
        :integral     => lambda{|n| n.gsub(/[^\d\.]/, '').to_f.round(n.include?('.') ? 1 : 0) },  #removes dots, so only suitable for claims ABOUT numbers, like 'digits add up an even number
        :numeric     =>  lambda{|n| n.gsub(/[^\d\.]/, '').to_f.send(n.include?('.') ? :to_f : :round) }, 
        :categorical =>  lambda{|x| x}
      }
    end

    def get_data!
      #randomly give a column's data
      return @data unless @data.nil?
      @data_columns.each{|column| column["type"] ||= "numeric" }
      @data_columns += @data_columns.select{|column| column["type"] == "numeric"}.map{|column| c = column.dup; c["type"] = "integral"; c}
      # reject those columns whose type doesn't have a cleaner (i.e. I haven't figured out categorical yet, but some are in the yaml file)
      @data_columns.reject!{|column| cleaners[column["type"].to_sym].nil? }
      column = @data_columns.find{|col| col["header"] == $settings_for_testing[:data_column] } || @data_columns.sample
      if column["nouns"]
        @nouns = column["nouns"].map{|n| Noun.new(n["noun"], n["noun_number"])}
      else
        @nouns = [Noun.new(column["noun"], column["noun_number"])]
      end
      @data_type = column["type"].to_sym

      @units = column["units"] || []
      @data = Hash[*@csv.map{|row| [row[@year_column_header].match(/\d{4}/)[0], 
        begin 
          cleaners[@data_type].call(row[column["header"]])
        rescue NoMethodError => e
          puts row.headers.inspect
          puts column["header"]
          raise e
        end
      ] }.flatten]
    end
    def commaify(number)
      # http://stackoverflow.com/questions/1078347/is-there-a-rails-trick-to-adding-commas-to-large-numbers
      number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    end
    def add_units(intro, number)
      return ["#{intro} #{number}"] if @units.size == 0
      @units.map do |unit|
        unit = {"word" => unit} unless unit.respond_to?(:has_key?) && unit.has_key?("word")
=begin
    units: 
      - degrees
      - word: "°"
        direction: "suffix"
        include_space: false
=end
        rounded = commaify(number.to_s.include?(".") ? number.round(1) : number)
        if unit["direction"] == "prefix"
          intro + " " + (unit["include_space"] == false ? '' : " ") + unit["word"] + rounded.to_s
        else # suffix
          intro + " " + rounded.to_s + (unit["include_space"] == false ? '' : " ") + unit["word"]
        end
      end
    end


  end

  class PunditBot
    def initialize
      populate_elections!
      @parties = PARTIES
      @datasets = YAML.load_file('data/correlates.yml')
    end
    def vectorize_politics_condition(politics_condition, party)
      victors = @elections[politics_condition.race][politics_condition.jurisdiction]
      tf_vector = Hash[*@election_years[politics_condition.race].each_with_index.map do |year, index| 
        if politics_condition.change
          [year, (politics_condition.control == (victors[year].match(/[A-Z]+/).to_s == party.wikipedia_symbol)) && 
            ((index != 0) && (victors[year].match(/[A-Z]+/).to_s != victors[@election_years[politics_condition.race][index-1]].match(/[A-Z]+/).to_s)) ]
        else
          [year, politics_condition.control == (victors[year].match(/[A-Z]+/).to_s == party.wikipedia_symbol)]
        end
      end.flatten]
      tf_vector 
    end

    def get_a_dataset!
      # @dataset = Dataset.new(  @datasets.select{|y| y["filename"] }.sample   )
      valid_datasets = @datasets.select{|y| y["filename"] }
      @dataset = Dataset.new(  valid_datasets.find{|d| d["filename"] == $settings_for_testing[:dataset] } || valid_datasets.sample )
      @dataset.get_data!
    end

    def find_data(hash_of_election_results, politics_condition)
      # for our data sets, find the earliest election year where the data condition matches that year's value in the vector_to_match every year or all but once.
      raise JeremyMessedUpError, "hash_of_election_results is not a hash! and everything follows from a contradiction..." unless hash_of_election_results.is_a? Hash
      # hash_of_election_results like {2012 => true, 2008 => true, 2004 => false} if we're talking about Dems winning WH

      # datasets must all look like this {2004 => 5.5, 2008 => 5.8, 2012 => 8.1 }
      get_a_dataset! # seems more exciting with the ! at the end, no?


      trues, falses = @dataset.data.to_a.partition.each_with_index{|val, idx| hash_of_election_results[val[0]] } #TODO: factor out; but something like it is used in data_claims

      # data_claims need a lambda and an English template
      # data_claims areto be divvied into types:
      #   those those apply to numbers themselves ('the number of atlantic hurricane deaths was an odd number' for noun 'atlantic hurricane deaths')
      #   those that apply to changes in numbers as the noun itself ('atlantic hurricane deaths decreased')
      #   those that apply to categorical data ('an AFC team won the World Series')
      data_claims = {
        # claims that apply to changes in numbers as the noun itself ('atlantic hurricane deaths decreased')
        :numeric => [
          DataClaim.new( lambda{|x, _|  x > trues.map{|a, b| b}.min }, 
            {
              :v => 'be',
              :tense => :past,
              :o => @dataset.add_units("greater than", trues.map{|a, b| b}.min) # obvi true for trues; if true for all of falses, unemployment was less than trues.min all the time,
            },
            "greater than"
          ),
          
          DataClaim.new( lambda{|x, _| x < trues.map{|a, b| b}.max }, 
            {
              :v => 'be',
              :tense => :past,
              :o => @dataset.add_units("less than", trues.map{|a, b| b}.max) # obvi true for trues; if true for all of falses, unemployment was less than trues.min all the time,
            },
            "less than"
          ),

          DataClaim.new( lambda{|x, _| x > 0 }, 
            {
              :v => 'is',
              :tense => :past,
              :o => "positive" 
            },
            "is positive"
          ),
          DataClaim.new( lambda{|x, _| x < 0 }, 
            {
              :v => 'is',
              :tense => :past,
              :o => "negative" 
            },
            "is negative"
          ),


          # these are duplicates
          DataClaim.new( lambda{|x, yr| x > @dataset.data[(yr.to_i-1).to_s] }, 
            {
              :v => 'grow',
              :tense => :past,
              # TODO: this is actually a complement
              :c => "from the previous year",
            }, 
            "grew from the previous year",
            1
          ), 
          DataClaim.new( lambda{|x, yr| x < @dataset.data[(yr.to_i-1).to_s] }, 
            {
              :v => 'decline',
              :tense => :past,
              # TODO: this is actually a complement
              :c => "from the previous year",
            }, 
            "declined from the previous year",
            1
          ), 
          DataClaim.new( lambda{|x, yr| x > @dataset.data[(yr.to_i-1).to_s] }, 
            {
              :v => 'grow',
              :tense => :past,
              # TODO: this is actually a complement
              :c => "year over year",
            }, 
            "grew year over year",
            1
          ), 
          DataClaim.new( lambda{|x, yr| x < @dataset.data[(yr.to_i-1).to_s] }, 
            {
              :v => 'decline',
              :tense => :past,
              # TODO: this is actually a complement
              :c => "year over year",
            }, 
            "declined year over year",
            1
          ),           
          DataClaim.new( lambda{|x, yr| x > @dataset.data[(yr.to_i-1).to_s] }, 
            {
              :v => 'increase',
              :tense => :past,
            }, 
            "increased",
            1
          ), 
          DataClaim.new( lambda{|x, yr| x < @dataset.data[(yr.to_i-1).to_s] }, 
            {
              :v => 'decline',
              :tense => :past,
            }, 
            "declined",
            1
          ), 


          DataClaim.new( lambda{|x, yr| x > @dataset.data[(yr.to_i-politics_condition.election_interval).to_s] }, 
            {
              :v => 'grow',
              :tense => :past,
              # TODO: this is actually a complement
              :c => "from the previous election year",
            }, 
            "grew from the previous election year",
            politics_condition.election_interval
          ), 
          DataClaim.new( lambda{|x, yr| x < @dataset.data[(yr.to_i-politics_condition.election_interval).to_s] }, 
            {
              :v => 'decline',
              :tense => :past,
              # TODO: this is actually a complement
              :c => "from the previous election year",
            }, 
            "declined from the previous election year",
            politics_condition.election_interval
          ), 
        ],

      # for categorial data
      # TODO: write this.
      # but what does it look like?
      # when the AFC won the Super Bowl?
      # when an NFC team was the Super Bowl winner
      :categorical => [
          DataClaim.new( lambda{|x, yr| }, 
            {
              :v => 'be',
              :tense => :past,
              :o => "asfd asdf TK"
              # TODO: this is actually a complement
            },
            "was"
          ), 
      ],

      # "integral" data claims are about the numbers qua numbers, e.g. odd, even. 
      :integral => [
          DataClaim.new( lambda{|x, _| x.to_s.chars.map(&:to_i).reduce(&:+).even? }, 
            # "<noun>'s digits add up to an even number",
            { 
              :n => lambda do |n| 
                              np = NLG.factory.create_noun_phrase('digit') 
                              np.set_plural true
                              last_word = (split_word = n.word.split(" ")).last
                              possessive = NLG.factory.create_noun_phrase(last_word) 
                              possessive.add_pre_modifier(split_word[0...-1].join(" "))
                              possessive.set_plural n.plural?
                              possessive.set_feature NLG::Feature::POSSESSIVE, true
                              np.set_specifier(possessive)
                              np
                           end,
              :v => 'add',
              :tense => :present,
              :c => 'up to an even number'
            },
            "adds up to an even number"
          ), 
          DataClaim.new( lambda{|x, _| x.to_s.chars.map(&:to_i).reduce(&:+).odd? }, 
            # "<noun>'s digits add up to an odd number",
            { 
              :n => lambda do |n| 
                              np = NLG.factory.create_noun_phrase('digit') 
                              np.set_feature NLG::Feature::NUMBER, NLG::NumberAgreement::PLURAL
                              last_word = (split_word = n.word.split(" ")).last
                              possessive = NLG.factory.create_noun_phrase(last_word) 
                              possessive.add_pre_modifier(split_word[0...-1].join(" "))
                              possessive.set_feature NLG::Feature::NUMBER, n.singular? ? NLG::NumberAgreement::SINGULAR : NLG::NumberAgreement::PLURAL
                              possessive.set_feature NLG::Feature::POSSESSIVE, true
                              np.set_specifier(possessive)
                              np
                           end,
              :v => 'add',
              :tense => :present,
              :c => 'up to an odd number'
            },
            "adds up to an odd number"
          ), 
          # removed for being kind of dumb.
          # DataClaim.new( lambda{|x, _| x.to_s.chars.to_a.last.to_i.even? }, 
          #   {
          #     :v => 'end',
          #     :tense => :past,
          #     # TODO: this is actually a complement
          #     :c => "in an even number"
          #   }
          # ), 
          # DataClaim.new( lambda{|x, _| x.to_s.chars.to_a.last.to_i.odd? }, #TODO: figure out how to get rid of these dupes (odd/even)
          #   {
          #     :v => 'end',
          #     :tense => :past,
          #     # TODO: this is actually a complement
          #     :c => "in an odd number"
          #   }
          # ), 
          DataClaim.new( lambda{|x, _| x.to_s.chars.to_a.first.to_i.even? }, 
            {
              :v => 'start',
              :tense => :past,
              # TODO: this is actually a complement
              :c => "with an even number"
            },
            "starts up to an even number"
          ), 
          DataClaim.new( lambda{|x, _| x.to_s.chars.to_a.first.to_i.odd? }, 
            {
              :v => 'start',
              :tense => :past,
              # TODO: this is actually a complement
              :c => "with an odd number"
            },
            "starts up to an odd number"
          ), 
          DataClaim.new( lambda{|x, _| x.round.even? }, 
            {
              :v => 'be',
              :tense => :past,
              # TODO: this is actually a complement
              :c => "an even number"
            },
            "is an even number"
          ), 
          DataClaim.new( lambda{|x, _| x.round.odd? }, 
            {
              :v => 'be',
              :tense => :past,
              # TODO: this is actually a complement
              :c => "an odd number"
            },
            "is an odd number"
          ), 

        ],
      }

      prediction_meta = nil
      data_claims[@dataset.data_type || "numeric"].product(POLARITIES).shuffle.find do |data_claim, polarity|
        next false unless $settings_for_testing[:data_claim].nil? || data_claim.name == $settings_for_testing[:data_claim]

        # find the most recent two years where the pattern is broken
        exceptional_year = nil
        start_year = nil
        data_claim_has_been_true_at_least_once = false
        if @dataset.max_year < @election_years[politics_condition.race].last
          false 
        else
          @election_years[politics_condition.race].reverse.each_with_index do |yr, idx|
            break if yr < (@dataset.min_year.to_i).to_s || (yr.to_i - data_claim.year_buffer).to_s < (@dataset.min_year.to_i - 1).to_s
            # find the second year for which the pattern doesn't fit



            # this might be wrong vv
            # if polarity is true
            #   if the condition is false this year, great
            #   or, if condition is true AND the hash_of_election_results is true, great
            # if polarity is false
            #   if the condition is true this year, great
            #   or, if condition is false AND the hash_of_election_results is false, great
            # otherwise, fail

            # in years where X occurs, Y occurs (exception)
            # for years where X does not occur, we don't care what happened.



            # I used to have this: if data_claim.condition.call(@dataset.data[yr], yr) == (hash_of_election_results[yr] == polarity) # if this year matches the pattern
            # but worried that it was too strict (because the converse of a statement was tested too, hence the error https://twitter.com/PunditBot/status/710460772900536320)
            # where "besides 2004" implies the GOP lost the WH then, but really it's just the time that the data claim was false (hurricane deaths declined yoy)
            # TODO: we need the condition to be true at least once. (otherwise, we get stuff like the Dems win every time hurricanes count is negative, which is only sort of true)
            if (!data_claim.condition.call(@dataset.data[yr], yr))
              # do nothing, because if we're talking about, e.g., when unemployment was an odd number, if it's even, we don't care.
              # puts "irrelevant: #{yr},  #{data_claim.condition.call(@dataset.data[yr], yr)}, #{@dataset.data[yr]}"
            elsif data_claim.condition.call(@dataset.data[yr], yr) && (hash_of_election_results[yr] == polarity) # if this year matches the pattern
              data_claim_has_been_true_at_least_once = true
              # do nothing, because it's true here
              # puts "match: #{yr},  #{data_claim.condition.call(@dataset.data[yr], yr)}, #{@dataset.data[yr]}"
            elsif exceptional_year.nil? # if this is the first year that doesn't match the pattern
              exceptional_year = yr
              # puts "exceptional_year: #{yr},  #{data_claim.condition.call(@dataset.data[yr], yr)}, #{@dataset.data[yr]}"
            else # `yr` is the second year that doesn't match the pattern
              start_year = (yr.to_i + politics_condition.election_interval).to_s 
              if start_year == exceptional_year
                start_year = (exceptional_year.to_i + politics_condition.election_interval).to_s 
                exceptional_year = nil
              end
              break
            end
          end
          if data_claim_has_been_true_at_least_once
            # if there is no start year set yet, take the minimum election year from the dataset
            start_year = @election_years[politics_condition.race].reject{|yr| yr < @dataset.min_year }.min if start_year.nil?

            if start_year > TOO_RECENT_TO_CARE_CUTOFF.to_s
              false
            else
              prediction_meta = {
                data_claim: data_claim,
                correlate_noun: @dataset.nouns,
                start_year: start_year, #never nil
                exceptional_year: exceptional_year, # maybe nil
                covered_years: @election_years[politics_condition.race].reject{|yr| yr < start_year || yr > @dataset.max_year },
                polarity: polarity,
                data_claim_type: @dataset.data_type,
                dataset_source: @dataset.source
              }
              break
            end
          else
            false
          end
        end
      end

      puts "Results: #{prediction_meta}" unless prediction_meta.nil?
      prediction_meta
    end

    def generate_prediction
      prediction = Prediction.new
      prediction.set(:party, party = @parties[ $settings_for_testing[:political_party] || @parties.keys.sample]) # TODO: party is our subj
      politics_condition = POLITICS_CONDITIONS[$settings_for_testing[:politics_condition] || POLITICS_CONDITIONS.keys.sample]
      politics_claim_truth_vector = vectorize_politics_condition(politics_condition, party)
      data = find_data(politics_claim_truth_vector, politics_condition)
      return nil if data.nil?
      # REFACTOR: this #set stuff is dumb
      prediction.set(:data_claim, data[:data_claim])
      prediction.set(:correlate_noun, data[:correlate_noun])

      prediction.set(:start_year, data[:start_year])
      prediction.set(:end_year, @dataset.max_year )
      prediction.set(:election_interval, politics_condition.election_interval)
      prediction.set(:covered_years, data[:covered_years])
      prediction.set(:data, @dataset.data)

      prediction.set(:politics_claim_truth_vector, politics_claim_truth_vector)
      prediction.set(:exceptional_year, data[:exceptional_year])
      prediction.set(:claim_polarity, data[:polarity])
      prediction.set(:politics_condition, politics_condition)
      prediction.set(:data_claim_type, data[:data_claim_type])
      prediction.set(:dataset, data[:dataset_source])
      prediction.templatize!

      prediction
    end

    def populate_elections!
      process_congress_csv!
      process_csv!
    end

    def process_congress_csv!
      csv = CSV.read('data/elections/Party_divisions_of_United_States_Congresses.csv', {:headers => true})
      @election_years ||= {}
      @election_years[:senate] = csv["election_year"].map{|year| year.match(/\d{4}/)[0] }
      @election_years[:house] = csv["election_year"].map{|year| year.match(/\d{4}/)[0] }
      @election_years[:congress] = csv["election_year"].map{|year| year.match(/\d{4}/)[0] }

      @elections ||= {}
      @elections[:senate]   = {}
      @elections[:house]    = {}
      @elections[:congress] = {}
      @elections[:senate]["USA"]   = {}
      @elections[:house]["USA"]    = {}
      @elections[:congress]["USA"] = {}
      csv.each do |row|
        @elections[:senate]["USA"][row["election_year"]] = row["Democrats (Senate)"].match(/^\*\d+\*/) ? 'D' : (row["Republicans (Senate)"].match(/^\*\d+\*/) ? 'R' : 'Other')
        @elections[:house]["USA"][row["election_year"]] = row["Democrats (House)"].match(/^\*\d+\*/) ? 'D' : (row["Republicans (House)"].match(/^\*\d+\*/) ? 'R' : 'Other')
        puts "Othered: #{row["Democrats (Senate)"]}, #{row["Republicans (Senate)"]}" if @elections[:senate]["USA"] == "Other"
        puts "Othered: #{row["Democrats (House)"] }, #{row["Republicans (Senate)"]}" if @elections[:house]["USA"] == "Other"
        @elections[:congress]["USA"][row["election_year"]] = @elections[:senate]["USA"][row["election_year"]] != @elections[:house]["USA"][row["election_year"]] ? "Split" : @elections[:senate]["USA"][row["election_year"]]
      end
    end
    #TODO: replace all instances of @election_years elsewhere in the codebase with @elections[@election_type][:election_years]

    def process_csv!
      # csv is download of source page, with source row added (linking to Wikipedia)
      csv = CSV.read('data/elections/List_of_United_States_presidential_election_results_by_state.csv', {:headers => true})
      @election_years ||= {}
      @election_years[:pres] = csv.headers.select{|h| h && h.match( /\d{4}/)}      

      usa_winner = {"State" => "USA", "Source" => csv.find{|row| row["State"] == "New York" }["Source"]}
      ["New York", "South Carolina", "Georgia" ].each do |colony| # these, between them, happen to have voted for a winner every year
        @election_years[:pres].each{|yr| usa_winner[yr] = csv.find{|row| row["State"] == colony}[yr] if (csv.find{|row| row["State"] == colony}[yr] || '').match(/^\*.+\*$/) }
      end
      @elections ||= {}
      @elections[:pres]   = {}
      csv.each{|row| @elections[:pres][row["State"]] = row.to_hash }
      @elections[:pres][usa_winner["State"]] = usa_winner
    end
  end
end