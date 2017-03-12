require 'csv'

module PunditBot
  class Party

    # TODO: formalize the relationship between the third alt-name ("Democrats") and the member_name ("Democrat")
    attr_reader :name, :alt_names, :wikipedia_symbol, :member_name
    def initialize(name, alt_names, wikipedia_symbol,  member_name)
      @name = name.first
      @alt_names = ([name] + alt_names).map{|name, num| Noun.new(name, num) }
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
    def max_by &blk
      @alt_names.max_by(&blk)
    end
    def min_by &blk
      @alt_names.min_by(&blk)
    end
  end
  PARTIES = {
    :dem => Party.new(["the Democratic Party", 1], [["the Dems", 2], ["the Democrats", 2]], 'D', "Democrat"), 
    :gop => Party.new(["the Republican Party", 1], [["the G.O.P.", 1], ["the Republicans", 2]], 'R', "Republican")
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
  end


  class Dataset
    attr_reader :name, :nouns, :min_year, :max_year, :data, :source, :data_type, :template_string
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

      # @units = column["units"] || []
      @template_string = column["template_string"]
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
  end
end
