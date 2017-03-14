require_relative './claims/adds_up_to_an_even_number_claim'
require_relative './claims/adds_up_to_an_odd_number_claim'
require_relative './claims/declined_claim'
require_relative './claims/declined_from_previous_election_year_claim'
require_relative './claims/declined_from_previous_year_claim'
require_relative './claims/declined_year_over_year_claim'
require_relative './claims/greater_than_claim'
require_relative './claims/grew_from_previous_election_year_claim'
require_relative './claims/grew_from_previous_year_claim'
require_relative './claims/grew_year_over_year_claim'
require_relative './claims/increased_claim'
require_relative './claims/is_an_even_number_claim'
require_relative './claims/is_an_odd_number_claim'
require_relative './claims/is_negative_claim'
require_relative './claims/is_positive_claim'
require_relative './claims/less_than_claim'
require_relative './claims/starts_with_an_even_number_claim'
require_relative './claims/starts_with_an_odd_number_claim'

module PunditBot
  class Dataset
    attr_reader :name, :nouns, :min_year, :max_year, :data, :source, :data_type, :template_string

    def initialize(obj)
      # create a dataset object from it
      # Notably: only one dataset object per spreadsheet
      # - this means a column from a dataset with one column is more likely to be used than a
      #   column from a dataset with many; this is intentional. We're randomly choosing datasets (for now).

      # read in CSV, process (e.g. numerics get gsubbed out non numeric chars.)
      # keep year column as string
      @name = obj['filename']
      @csv = CSV.read("data/correlates/#{obj['filename']}", headers: true)
      @year_column_header = obj['year_column_header']
      sorted_years = @csv.map { |row| row[@year_column_header].match(/\d{4}/)[0] }.sort
      @min_year = sorted_years.first
      @max_year = sorted_years.last
      @data_columns = obj['data_columns']
      @source = obj['source']
    end

    def cleaners
      {
        integral: ->(n) { n.gsub(/[^\d\.]/, '').to_f.round(n.include?('.') ? 1 : 0) }, # removes dots, so only suitable for claims ABOUT numbers, like 'digits add up an even number
        numeric: ->(n) { n.gsub(/[^\d\.]/, '').to_f.send(n.include?('.') ? :to_f : :round) },
        categorical: ->(x) { x }
      }
    end

    def get_data!
      # randomly give a column's data
      return @data unless @data.nil?
      @data_columns.each { |column| column['type'] ||= 'numeric' }
      @data_columns += @data_columns.select { |column| column['type'] == 'numeric' }.map { |column| c = column.dup; c['type'] = 'integral'; c }
      # reject those columns whose type doesn't have a cleaner (i.e. I haven't figured out categorical yet, but some are in the yaml file)
      @data_columns.reject! { |column| cleaners[column['type'].to_sym].nil? }
      column = @data_columns.sample
      if column['nouns']
        @nouns = column['nouns'].map { |n| Noun.new(n['noun'], n['noun_number']) }
      else
        @nouns = [Noun.new(column['noun'], column['noun_number'])]
      end
      @data_type = column['type'].to_sym

      # @units = column["units"] || []
      @template_string = column['template_string']
      @data = Hash[*@csv.map do |row|
        [row[@year_column_header].match(/\d{4}/)[0],
         begin
                        cleaners[@data_type].call(row[column['header']])
                      rescue NoMethodError => e
                        puts row.headers.inspect
                        puts column['header']
                        raise e
                      end]
      end.flatten]
    end

    def data_claims(years_when_poltical_condition_true, election_interval)

      # data_claims need a lambda and an English template
      # data_claims areto be divvied into types:
      #   those those apply to numbers themselves ('the number of atlantic hurricane deaths was an odd number' for noun 'atlantic hurricane deaths')
      #   those that apply to changes in numbers as the noun itself ('atlantic hurricane deaths decreased')
      #   those that apply to categorical data ('an AFC team won the World Series')
      data_claims = {
        # claims that apply to changes in numbers as the noun itself ('atlantic hurricane deaths decreased')
        numeric: [
          Claims::GreaterThanClaim.new(data, years_when_poltical_condition_true, election_interval, template_string),
          Claims::LessThanClaim.new(data, years_when_poltical_condition_true, election_interval, template_string),
          Claims::IsPositiveClaim.new(data, years_when_poltical_condition_true, election_interval),
          Claims::IsNegativeClaim.new(data, years_when_poltical_condition_true, election_interval),
          Claims::GrewFromPreviousYearClaim.new(data, years_when_poltical_condition_true, 1),
          Claims::DeclinedFromPreviousYearClaim.new(data, years_when_poltical_condition_true, 1),
          Claims::GrewYearOverYearClaim.new(data, years_when_poltical_condition_true, 1),
          Claims::DeclinedYearOverYearClaim.new(data, years_when_poltical_condition_true, 1),
          Claims::IncreasedClaim.new(data, years_when_poltical_condition_true, 1),
          Claims::DeclinedClaim.new(data, years_when_poltical_condition_true, 1),
          Claims::GrewFromPreviousElectionYearClaim.new(data, years_when_poltical_condition_true, election_interval),
          Claims::DeclinedFromPreviousElectionYearClaim.new(data, years_when_poltical_condition_true, election_interval)
        ],

        # "integral" data claims are about the numbers qua numbers, e.g. odd, even.
        integral: [
          Claims::AddsUpToAnEvenNumberClaim.new(data, years_when_poltical_condition_true, election_interval),
          Claims::AddsUpToAnOddNumberClaim.new(data, years_when_poltical_condition_true, election_interval),
          Claims::StartsWithAnEvenNumberClaim.new(data, years_when_poltical_condition_true, election_interval),
          Claims::StartsWithAnOddNumberClaim.new(data, years_when_poltical_condition_true, election_interval),
          Claims::IsAnEvenNumberClaim.new(data, years_when_poltical_condition_true, election_interval),
          Claims::IsAnOddNumberClaim.new(data, years_when_poltical_condition_true, election_interval)
        ]
      }
    end
  end
end
