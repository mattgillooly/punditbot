module PunditBot::Claims
  class LessThanClaim < PunditBot::DataClaim
    def condition(x, _)
      x < data_when_political_condition_true.max
    end

    def template
      {
        v: 'be',
        tense: :past,
        o: 'less',
        prepositional_phrases: [{
          preposition: 'than',
          rest: {
            noun: data_when_political_condition_true.map { |_a, b| b }.max.to_s,
            template_string: (ts = template_string).respond_to?(:sample) ? ts.sample : ts # TODO: should be rephraseable
          }
        }]
      }
    end
  end
end
