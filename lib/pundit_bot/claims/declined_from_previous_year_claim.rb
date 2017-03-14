module PunditBot::Claims
  class DeclinedFromPreviousYearClaim < PunditBot::DataClaim
    def condition(x, year)
      x < data[(year.to_i - 1).to_s]
    end

    def template
      {
        v: 'decline',
        tense: :past,
        # TODO: this is actually a complement
        c: 'from the previous year'
      }
    end
  end
end
