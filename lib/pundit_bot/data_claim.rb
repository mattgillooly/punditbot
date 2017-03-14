require 'simplernlg'
puts 'Warning, this only works on JRuby but you can check for syntax errors more quickly in MRE' if RUBY_PLATFORM != 'java'

module PunditBot
  class DataClaim
    NLG = SimplerNLG::NLG

    attr_reader :data, :years_when_poltical_condition_true, :election_interval, :template_string, :year_buffer, :data_when_political_condition_true

    def initialize(data, years_when_poltical_condition_true, election_interval, template_string = nil, year_buffer = nil)
      @data = data
      @years_when_poltical_condition_true = years_when_poltical_condition_true
      @election_interval = election_interval
      @template_string = template_string
      @year_buffer = year_buffer || 0

      @data_when_political_condition_true = data.values_at(*years_when_poltical_condition_true)
    end
  end
end
