module PunditBot::Claims
  class IsNegativeClaim < PunditBot::DataClaim
    def condition(x, _)
      x < 0
    end

    def template
      {
        v: 'is',
        tense: :past,
        o: 'negative'
      }
    end
  end
end
