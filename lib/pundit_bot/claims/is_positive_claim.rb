module PunditBot::Claims
  class IsPositiveClaim < PunditBot::DataClaim
    def condition(x, _)
      x > 0
    end

    def template
      {
        v: 'is',
        tense: :past,
        o: 'positive'
      }
    end
  end
end
