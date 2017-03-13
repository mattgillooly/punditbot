require 'simplernlg' # if RUBY_PLATFORM == 'java'
puts 'Warning, this only works on JRuby but you can check for syntax errors more quickly in MRE' if RUBY_PLATFORM != 'java'

module PunditBot
  class Dataset
    NLG = SimplerNLG::NLG

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
      column = @data_columns.find { |col| col['header'] == $settings_for_testing[:data_column] } || @data_columns.sample
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
      data_when_political_condition_true = data.values_at(*years_when_poltical_condition_true)

      # data_claims need a lambda and an English template
      # data_claims areto be divvied into types:
      #   those those apply to numbers themselves ('the number of atlantic hurricane deaths was an odd number' for noun 'atlantic hurricane deaths')
      #   those that apply to changes in numbers as the noun itself ('atlantic hurricane deaths decreased')
      #   those that apply to categorical data ('an AFC team won the World Series')
      data_claims = {
        # claims that apply to changes in numbers as the noun itself ('atlantic hurricane deaths decreased')
        numeric: [
          DataClaim.new(->(x, _) { x > data_when_political_condition_true.min},
                        {
                          v: 'be',
                          tense: :past,
                          o: 'greater',
                          prepositional_phrases: [{
                            preposition: 'than',
                            rest: {
                              noun: data_when_political_condition_true.map { |_a, b| b }.min.to_s, # obvi true for trues; if true for all of falses, unemployment was less than trues.min all the time,
                              template_string: (ts = template_string).respond_to?(:sample) ? ts.sample : ts # TODO should be rephraseable
                            }
                          }]
                        },
                        'greater than'),

          DataClaim.new(->(x, _) { x < data_when_political_condition_true.max},
                        {
                          v: 'be',
                          tense: :past,
                          o: 'less',
                          prepositional_phrases: [{
                            preposition: 'than',
                            rest: {
                              noun: data_when_political_condition_true.map { |_a, b| b }.max.to_s,
                              template_string: (ts = template_string).respond_to?(:sample) ? ts.sample : ts # TODO: should be rephraseable
                            }
                          }]
                        },
                        'less than'),

          DataClaim.new(->(x, _) { x > 0 },
                        {
                          v: 'is',
                          tense: :past,
                          o: 'positive'
                        },
                        'is positive'),
          DataClaim.new(->(x, _) { x < 0 },
                        {
                          v: 'is',
                          tense: :past,
                          o: 'negative'
                        },
                        'is negative'),

          # these are duplicates
          DataClaim.new(->(x, yr) { x > data[(yr.to_i - 1).to_s] },
                        {
                          v: 'grow',
                          tense: :past,
                          # TODO: this is actually a complement
                          c: 'from the previous year'
                        },
                        'grew from the previous year',
                        1),
          DataClaim.new(->(x, yr) { x < data[(yr.to_i - 1).to_s] },
                        {
                          v: 'decline',
                          tense: :past,
                          # TODO: this is actually a complement
                          c: 'from the previous year'
                        },
                        'declined from the previous year',
                        1),
          DataClaim.new(->(x, yr) { x > data[(yr.to_i - 1).to_s] },
                        {
                          v: 'grow',
                          tense: :past,
                          # TODO: this is actually a complement
                          c: 'year over year'
                        },
                        'grew year over year',
                        1),
          DataClaim.new(->(x, yr) { x < data[(yr.to_i - 1).to_s] },
                        {
                          v: 'decline',
                          tense: :past,
                          # TODO: this is actually a complement
                          c: 'year over year'
                        },
                        'declined year over year',
                        1),
          DataClaim.new(->(x, yr) { x > data[(yr.to_i - 1).to_s] },
                        {
                          v: 'increase',
                          tense: :past
                        },
                        'increased',
                        1),
          DataClaim.new(->(x, yr) { x < data[(yr.to_i - 1).to_s] },
                        {
                          v: 'decline',
                          tense: :past
                        },
                        'declined',
                        1),

          DataClaim.new(->(x, yr) { x > data[(yr.to_i - election_interval).to_s] },
                        {
                          v: 'grow',
                          tense: :past,
                          # TODO: this is actually a complement
                          c: 'from the previous election year'
                        },
                        'grew from the previous election year',
                        election_interval),
          DataClaim.new(->(x, yr) { x < data[(yr.to_i - election_interval).to_s] },
                        {
                          v: 'decline',
                          tense: :past,
                          # TODO: this is actually a complement
                          c: 'from the previous election year'
                        },
                        'declined from the previous election year',
                        election_interval)
        ],

        # for categorial data
        # TODO: write this.
        # but what does it look like?
        # when the AFC won the Super Bowl?
        # when an NFC team was the Super Bowl winner
        categorical: [
          DataClaim.new(->(x, yr) {},
                        {
                          v: 'be',
                          tense: :past,
                          o: 'asfd asdf TK'
                          # TODO: this is actually a complement
                        },
                        'was')
        ],

        # "integral" data claims are about the numbers qua numbers, e.g. odd, even.
        integral: [
          DataClaim.new(->(x, _) { x.to_s.chars.map(&:to_i).reduce(&:+).even? },
                        # "<noun>'s digits add up to an even number",
                        {
                          n: lambda do |n|
                               np = NLG.factory.create_noun_phrase('digit')
                               np.set_plural true
                               last_word = (split_word = (n.respond_to?(:word) ? n.word : n).split(' ')).last
                               possessive = NLG.factory.create_noun_phrase(last_word)
                               possessive.add_pre_modifier(split_word[0...-1].join(' '))
                               possessive.set_plural n.plural?
                               possessive.set_feature NLG::Feature::POSSESSIVE, true
                               np.set_specifier(possessive)
                               np
                             end,
                          v: 'add',
                          tense: :present,
                          c: 'up to an even number'
                        },
                        'adds up to an even number'),
          DataClaim.new(->(x, _) { x.to_s.chars.map(&:to_i).reduce(&:+).odd? },
                        # "<noun>'s digits add up to an odd number",
                        {
                          n: lambda do |n|
                               np = NLG.factory.create_noun_phrase('digit')
                               np.set_feature NLG::Feature::NUMBER, NLG::NumberAgreement::PLURAL
                               last_word = (split_word = n.word.split(' ')).last
                               possessive = NLG.factory.create_noun_phrase(last_word)
                               possessive.add_pre_modifier(split_word[0...-1].join(' '))
                               possessive.set_feature NLG::Feature::NUMBER, n.singular? ? NLG::NumberAgreement::SINGULAR : NLG::NumberAgreement::PLURAL
                               possessive.set_feature NLG::Feature::POSSESSIVE, true
                               np.set_specifier(possessive)
                               np
                             end,
                          v: 'add',
                          tense: :present,
                          c: 'up to an odd number'
                        },
                        'adds up to an odd number'),
          DataClaim.new(->(x, _) { x.to_s.chars.to_a.first.to_i.even? },
                        {
                          v: 'start',
                          tense: :past,
                          # TODO: this is actually a complement
                          c: 'with an even number'
                        },
                        'starts up to an even number'),
          DataClaim.new(->(x, _) { x.to_s.chars.to_a.first.to_i.odd? },
                        {
                          v: 'start',
                          tense: :past,
                          # TODO: this is actually a complement
                          c: 'with an odd number'
                        },
                        'starts up to an odd number'),
          DataClaim.new(->(x, _) { x.round.even? },
                        {
                          v: 'be',
                          tense: :past,
                          # TODO: this is actually a complement
                          c: 'an even number'
                        },
                        'is an even number'),
          DataClaim.new(->(x, _) { x.round.odd? },
                        {
                          v: 'be',
                          tense: :past,
                          # TODO: this is actually a complement
                          c: 'an odd number'
                        },
                        'is an odd number'),
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

        ]
      }
    end
  end
end
