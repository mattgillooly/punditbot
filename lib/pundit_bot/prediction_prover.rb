module PunditBot
  class PredictionProver
    def initialize(covered_years, data, data_claim, politics_claim_truth_vector)
      @covered_years = covered_years
      @data = data
      @data_claim = data_claim
      @politics_claim_truth_vector = politics_claim_truth_vector
    end

    def prove_it!
      ''" e.g.
      2012  2008  2004  2000  1996  1992  1988
      7.8   8.2   7.9   8.1   etc   etc   etc
      true  true  false false true  true  false
      "''

      # max length in chars of each of the numbers from the dataset
      max_data_length = [data_for_covered_years.map { |d| d.to_s.size }.max, 4].max

      [@covered_years, data_for_covered_years, data_truth, victor].map { |row| row.map { |x| x.to_s.ljust(max_data_length) }.join("\t") }.join("\n")
    end

    private

    def data_for_covered_years
      @data_for_covered_years ||= @covered_years.map { |yr| @data[yr] }
    end

    def data_truth
      data_for_covered_years.zip(@covered_years).map do |datum, yr|
        begin
          @data_claim.condition.call(datum, yr)
        rescue ArgumentError
          nil
        end
      end
    end

    def victor
      @covered_years.map { |yr| @politics_claim_truth_vector[yr] }
    end
  end
end
