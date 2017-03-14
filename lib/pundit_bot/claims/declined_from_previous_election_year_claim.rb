module PunditBot::Claims
  class DeclinedFromPreviousElectionYearClaim < PunditBot::DataClaim
    def condition(x, year)
      x < data[(year.to_i - election_interval).to_s]
    end

    def template
      {
        v: 'decline',
        tense: :past,
        # TODO: this is actually a complement
        c: 'from the previous election year'
      }
    end
  end
end
