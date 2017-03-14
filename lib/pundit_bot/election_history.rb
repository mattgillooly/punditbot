module PunditBot
  class ElectionHistory
    def initialize
      process_congress_csv!
      process_csv!
    end

    def process_congress_csv!
      csv = CSV.read('data/elections/Party_divisions_of_United_States_Congresses.csv', headers: true)
      @election_years ||= {}
      @election_years[:senate] = csv['election_year'].map { |year| year.match(/\d{4}/)[0] }
      @election_years[:house] = csv['election_year'].map { |year| year.match(/\d{4}/)[0] }
      @election_years[:congress] = csv['election_year'].map { |year| year.match(/\d{4}/)[0] }

      @elections ||= {}
      @elections[:senate]   = {}
      @elections[:house]    = {}
      @elections[:congress] = {}
      @elections[:senate]['USA']   = {}
      @elections[:house]['USA']    = {}
      @elections[:congress]['USA'] = {}
      csv.each do |row|
        @elections[:senate]['USA'][row['election_year']] = row['Democrats (Senate)'] =~ /^\*\d+\*/ ? 'D' : (row['Republicans (Senate)'] =~ /^\*\d+\*/ ? 'R' : 'Other')
        @elections[:house]['USA'][row['election_year']] = row['Democrats (House)'] =~ /^\*\d+\*/ ? 'D' : (row['Republicans (House)'] =~ /^\*\d+\*/ ? 'R' : 'Other')
        puts "Othered: #{row['Democrats (Senate)']}, #{row['Republicans (Senate)']}" if @elections[:senate]['USA'] == 'Other'
        puts "Othered: #{row['Democrats (House)']}, #{row['Republicans (Senate)']}" if @elections[:house]['USA'] == 'Other'
        @elections[:congress]['USA'][row['election_year']] = @elections[:senate]['USA'][row['election_year']] != @elections[:house]['USA'][row['election_year']] ? 'Split' : @elections[:senate]['USA'][row['election_year']]
      end
    end
    # TODO: replace all instances of @election_years elsewhere in the codebase with @elections[@election_type][:election_years]

    def process_csv!
      # csv is download of source page, with source row added (linking to Wikipedia)
      csv = CSV.read('data/elections/List_of_United_States_presidential_election_results_by_state.csv', headers: true)
      @election_years ||= {}
      @election_years[:pres] = csv.headers.select { |h| h && h.match(/\d{4}/) }

      usa_winner = { 'State' => 'USA', 'Source' => csv.find { |row| row['State'] == 'New York' }['Source'] }
      ['New York', 'South Carolina', 'Georgia'].each do |colony| # these, between them, happen to have voted for a winner every year
        @election_years[:pres].each { |yr| usa_winner[yr] = csv.find { |row| row['State'] == colony }[yr] if (csv.find { |row| row['State'] == colony }[yr] || '') =~ /^\*.+\*$/ }
      end
      @elections ||= {}
      @elections[:pres] = {}
      csv.each { |row| @elections[:pres][row['State']] = row.to_hash }
      @elections[:pres][usa_winner['State']] = usa_winner
    end

    def vectorize_politics_condition(politics_condition, party)
      victors = @elections[politics_condition.race][politics_condition.jurisdiction]
      race_election_years = @election_years[politics_condition.race]

      tf_vector = Hash[*race_election_years.each_with_index.flat_map do |year, index|
        winner_symbol = victors[year].match(/[A-Z]+/).to_s
        actual_control = (winner_symbol == party.wikipedia_symbol)

        previous_election_year = race_election_years[index - 1]
        previous_winner_symbol = victors[previous_election_year].match(/[A-Z]+/).to_s
        control_changed = previous_winner_symbol && (winner_symbol != previous_winner_symbol)

        [year, politics_condition.satisfied?(actual_control, control_changed)]
      end]
      tf_vector
    end

    def past_race_years(race)
      @election_years[race]
    end
  end
end
