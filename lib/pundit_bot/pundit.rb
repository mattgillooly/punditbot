require 'csv'
require 'yaml'

module PunditBot
  class Pundit
    def initialize
      @election_history = ElectionHistory.new
      @parties = PARTIES
      @datasets = YAML.load_file('data/correlates.yml')
    end

    def get_a_dataset!
      # @dataset = Dataset.new(  @datasets.select{|y| y["filename"] }.sample   )
      valid_datasets = @datasets.select { |y| y['filename'] }
      @dataset = Dataset.new(valid_datasets.find { |d| d['filename'] == $settings_for_testing[:dataset] } || valid_datasets.sample)
      @dataset.get_data!
    end

    def find_correlating_time_series(hash_of_election_results, politics_condition)
      # for our data sets, find the earliest election year where the data condition matches that year's value in the vector_to_match every year or all but once.
      raise JeremyMessedUpError, 'hash_of_election_results is not a hash! and everything follows from a contradiction...' unless hash_of_election_results.is_a? Hash
      # hash_of_election_results like {2012 => true, 2008 => true, 2004 => false} if we're talking about Dems winning WH

      # datasets must all look like this {2004 => 5.5, 2008 => 5.8, 2012 => 8.1 }
      get_a_dataset! # seems more exciting with the ! at the end, no?

      years_when_polticial_claim_true = hash_of_election_results.select{|_k, v| v}.keys
      data_claims = @dataset.data_claims(years_when_polticial_claim_true, politics_condition.election_interval)

      correlate_meta = nil
      data_claims[@dataset.data_type || 'numeric'].product(POLARITIES).shuffle.find do |data_claim, polarity|
        next false unless $settings_for_testing[:data_claim].nil? || data_claim.name == $settings_for_testing[:data_claim]

        # find the most recent two years where the pattern is broken
        exceptional_year = nil
        start_year = nil
        data_claim_has_been_true_at_least_once = false
        past_race_years = @election_history.past_race_years(politics_condition.race)

        if @dataset.max_year < past_race_years.last
          false
        else
          past_race_years.reverse.each_with_index do |yr, _idx|
            # the output here is the "start year" when the political condition relates to the data claim (and optionally an exception year)

            # in years where X occurs
            #    does the political condition obtain?
            #    if not, process it as the exception or as the election before our start year
            # for years where X does not occur, we don't care what happened.

            if yr < @dataset.min_year.to_i.to_s
              # if we don't have data for this year, give up.
              break
            end

            year_is_valid = (yr.to_i - data_claim.year_buffer).to_s >= @dataset.min_year.to_i.to_s
            # some data claims require data going back before the `yr`. if we can do that, then year_is_valid = true

            data_claim_applies_this_year = year_is_valid && data_claim.condition.call(@dataset.data[yr], yr)
            # four possibilities: data claim is true or false; the party won or lost the election
            #    if the data claim is false, we don't care about the election that year
            #    that is to say, if we're making a claim about what happens when X prices are an odd number
            #      if they're even, we don't care what happened (since it doesn't affect the 'relationship')

            if !year_is_valid || (data_claim_applies_this_year && hash_of_election_results[yr] != polarity)
              # we only have to do fancy stuff if this year doesn't fit the pattern (i.e. if the data claim applies, but the political one doesn't)
              # or if this is the first invalid year of the set.

              if year_is_valid && exceptional_year.nil?
                # if this is the first time the data claim has been true, but the political claim hasn't been
                # then just mark it as an exception
                exceptional_year = yr
              else
                # stop looking because we've either found
                # 1. two cases where the data claim has been true, but the political claim hasn't been, OR
                # 2. the data doesn't go back any farther
                start_year = (yr.to_i + politics_condition.election_interval).to_s
                if start_year == exceptional_year
                  # avoid saying somtehing like "since 1980 except 1980"
                  start_year = (exceptional_year.to_i + politics_condition.election_interval).to_s
                  exceptional_year = nil
                end
                break
              end
            else
              # we just want to make sure the data claim is true at least once (not a high bar!)
              # so we don't say stuff that's equivalent to "in years where pigs can fly, the X occurs"
              #   (or, in years where coffee costs more than a million dollars)
              data_claim_has_been_true_at_least_once ||= data_claim_applies_this_year
            end
          end

          if data_claim_has_been_true_at_least_once
            # if there is no start year set yet, take the minimum election year from the dataset
            start_year = past_race_years.reject { |yr| yr < @dataset.min_year }.min if start_year.nil?

            if start_year > TOO_RECENT_TO_CARE_CUTOFF.to_s
              false
            else
              correlate_meta = {
                data_claim: data_claim,
                correlate_noun: @dataset.nouns,
                start_year: start_year, # never nil
                exceptional_year: exceptional_year, # maybe nil
                covered_years: past_race_years.reject { |yr| yr < start_year || yr > @dataset.max_year },
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

      puts "Results: #{correlate_meta}" unless correlate_meta.nil?
      correlate_meta
    end

    def generate_prediction
      # prediction.set(:party, party = @parties[ $settings_for_testing[:political_party] || @parties.keys.sample]) # TODO: party is our subj
      party = @parties[$settings_for_testing[:political_party] || @parties.keys.sample]
      politics_condition = POLITICS_CONDITIONS[$settings_for_testing[:politics_condition] || POLITICS_CONDITIONS.keys.sample]
      politics_claim_truth_vector = @election_history.vectorize_politics_condition(politics_condition, party)
      correlating_time_series = find_correlating_time_series(politics_claim_truth_vector, politics_condition)
      return nil if correlating_time_series.nil?

      party.allow_singular! if politics_condition.race == :pres

      raise IOError, 'correlating_time_series[:data_claim].template was nil' if correlating_time_series[:data_claim].template.nil?

      Prediction.build(party, correlating_time_series, politics_condition, @dataset, politics_claim_truth_vector)
    end
  end
end
