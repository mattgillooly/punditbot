module PunditBot::Claims
  class IsAnEvenNumberClaim < PunditBot::DataClaim
    def condition(x, _year)
     x.round.even?
    end

    def template
      {
        v: 'is',
        tense: :past,
        # TODO: this is actually a complement
        c: 'an even number'
      }
    end
  end
end
