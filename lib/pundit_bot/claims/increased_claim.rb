module PunditBot::Claims
  class IncreasedClaim < PunditBot::DataClaim
    def condition(x, year)
      x > data[(year.to_i - 1).to_s]
    end

    def template
      {
        v: 'increased',
        tense: :past
      }
    end
  end
end
