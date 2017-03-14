module PunditBot::Claims
  class DeclinedYearOverYearClaim < PunditBot::DataClaim
    def condition(x, year)
      x < data[(year.to_i - 1).to_s]
    end

    def template
      {
        v: 'decline',
        tense: :past,
        # TODO: this is actually a complement
        c: 'year over year'
      }
    end
  end
end
