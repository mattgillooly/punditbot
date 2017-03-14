module PunditBot::Claims
  class StartsWithAnEvenNumberClaim < PunditBot::DataClaim
    def condition(x, _year)
     x.to_s.chars.to_a.first.to_i.even?
    end

    def template
      {
        v: 'start',
        tense: :past,
        # TODO: this is actually a complement
        c: 'with an even number'
      }
    end
  end
end
