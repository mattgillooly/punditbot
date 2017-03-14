module PunditBot::Claims
  class DeclinedClaim < PunditBot::DataClaim
    def condition(x, year)
      x < data[(year.to_i - 1).to_s]
    end

    def template
      {
        v: 'decline',
        tense: :past
      }
    end
  end
end
