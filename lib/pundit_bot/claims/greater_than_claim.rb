module PunditBot::Claims
  class GreaterThanClaim < PunditBot::DataClaim
    def condition(x, _)
      x > data_when_political_condition_true.min
    end

    def template
      {
        v: 'be',
        tense: :past,
        o: 'greater',
        prepositional_phrases: [{
          preposition: 'than',
          rest: {
            noun: data_when_political_condition_true.map { |_a, b| b }.min.to_s, # obvi true for trues; if true for all of falses, unemployment was less than trues.min all the time,
            template_string: (ts = template_string).respond_to?(:sample) ? ts.sample : ts # TODO should be rephraseable
          }
        }]
      }
    end
  end
end
