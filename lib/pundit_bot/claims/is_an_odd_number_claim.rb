module PunditBot::Claims
  class IsAnOddNumberClaim < PunditBot::DataClaim
    def condition(x, _year)
     x.round.odd?
    end

    def template
      {
        v: 'is',
        tense: :past,
        # TODO: this is actually a complement
        c: 'an odd number'
      }
    end
  end
end
