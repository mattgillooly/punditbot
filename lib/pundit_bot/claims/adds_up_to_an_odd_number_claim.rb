module PunditBot::Claims
  class AddsUpToAnOddNumberClaim < PunditBot::DataClaim
    def condition(x, _year)
      x.to_s.chars.map(&:to_i).reduce(&:+).odd?
    end

    def template
      # "<noun>'s digits add up to an odd number",
      {
        n: lambda do |n|
             np = NLG.factory.create_noun_phrase('digit')
             np.set_plural true
             last_word = (split_word = (n.respond_to?(:word) ? n.word : n).split(' ')).last
             possessive = NLG.factory.create_noun_phrase(last_word)
             possessive.add_pre_modifier(split_word[0...-1].join(' '))
             possessive.set_plural n.plural?
             possessive.set_feature NLG::Feature::POSSESSIVE, true
             np.set_specifier(possessive)
             np
           end,
        v: 'add',
        tense: :present,
        c: 'up to an odd number'
      }
    end
  end
end
