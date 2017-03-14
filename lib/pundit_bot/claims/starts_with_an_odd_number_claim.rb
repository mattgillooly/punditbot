module PunditBot::Claims
  class StartsWithAnOddNumberClaim < PunditBot::DataClaim
    def condition(x, _year)
     x.to_s.chars.to_a.first.to_i.odd?
    end

    def template
      {
        v: 'start',
        tense: :past,
        # TODO: this is actually a complement
        c: 'with an odd number'
      }
    end
  end
end
