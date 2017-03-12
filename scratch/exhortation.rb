
    # def old_exhortation
    #   @data_phrase
    #   party_member_name, claim_polarity = *[[@prediction_meta[:party].member_name, @prediction_meta[:claim_polarity]], [@prediction_meta[:party].member_name.downcase.include?("democrat") ? "Republican" : "Democrat", !@prediction_meta[:claim_polarity]]].sample
    #   @data_phrase.set_feature(NLG::Feature::TENSE, NLG::Tense::PRESENT)
    #   # @data_phrase.set_feature(NLG::Feature::SUPRESSED_COMPLEMENTISER, true)
    #   @data_phrase.set_feature(NLG::Feature::COMPLEMENTISER, 'that') # requires 3eed77f5bf6ce0e2655d80ce3ba453696ad5bb8a in my fork of SimpleNLG
    #   @data_phrase.set_feature(NLG::Feature::NEGATED,  @prediction_meta[:politics_condition].control ? !claim_polarity : claim_polarity)

    #   pp = NLG.factory.create_preposition_phrase(NLG.factory.create_noun_phrase('this', 'year'))
    #   # What I can generate:
    #   #   Democrats should hope that bears killed more than 10 people this year.
    #   #   This year, Democrats, you need to hope that bears killed more than 10 people.
    #   #   If you're a Democrat, this year, you should hope that bears killed more than 10 people.
    #   #   Democrats, hope that bears killed more than 10 people this year.
    #   # What I'd like to generate:
    #   #   Democrats should hope for more snow this year...
    #   #   Democrats should hope Central Park snow increases year over year.
    #   #   If you're a Democrat, you should hope _________
    #   #   If you're a Democrat, you want vegetable use to increase this year.
    #   #   Republicans, you need to hope that DDDDDDD is an even number this year.

    #   case [:you, :if, :imperative].sample # removed :bare because it sucks
    #   when :bare
    #     np = NLG.factory.create_noun_phrase(party_member_name)
    #     np.set_feature(NLG::Feature::NUMBER, NLG::NumberAgreement::PLURAL)
    #     phrase = NLG.phrase({
    #       :s => np,
    #       :number => :plural,
    #       :v => 'hope',
    #       :modal => "should",
    #       :tense => :present,
    #     })
    #     phrase.add_complement(@data_phrase)
    #     modifiers = [:add_post_modifier, :add_front_modifier]
    #     phrase.send(modifiers.sample,  pp)

    #     NLG.realizer.setCommaSepCuephrase(true)
    #   when :you
    #     phrase = NLG.phrase({
    #       :s => "you",
    #       :number => :plural,
    #       :v => 'need',
    #       :tense => :present,
    #     })

    #     inner = NLG.phrase({
    #       :v => "hope"
    #     })

    #     inner.add_complement(@data_phrase)

    #     party_np = NLG.factory.create_noun_phrase(party_member_name)
    #     party_np.set_feature(NLG::Feature::NUMBER, NLG::NumberAgreement::PLURAL)
    #     phrase.add_front_modifier(party_np) # cue phrase

    #     modifiers = [:add_post_modifier, :add_front_modifier]
    #     phrase.send(modifiers.sample,  pp)
    #     inner.set_feature(NLG::Feature::FORM, NLG::Form::INFINITIVE)
    #     phrase.add_complement(inner)
    #     NLG.realizer.setCommaSepCuephrase(true)
    #   when :if
    #     phrase = NLG.phrase({
    #       :s => "you",
    #       :number => :plural,
    #       :v => 'hope',
    #       :modal => "should",
    #       :tense => :present,
    #     })
    #     phrase.add_complement(@data_phrase)
    #     phrase.add_front_modifier("if you're a " + party_member_name)
    #     modifiers = [:add_post_modifier, :add_front_modifier]
    #     phrase.send(modifiers.sample,  pp)

    #     NLG.realizer.setCommaSepCuephrase(true)
    #   when :imperative
    #     phrase = NLG.phrase({
    #       :number => :plural,
    #       :v => ['hope', 'pray'].sample,
    #       :tense => :present,
    #     })
    #     phrase.add_complement(@data_phrase)
    #     modifiers = [:add_post_modifier, :add_front_modifier]
    #     phrase.send(modifiers.sample,  pp)
    #     phrase.set_feature(NLG::Feature::FORM, NLG::Form::IMPERATIVE)
    #     np = NLG.factory.create_noun_phrase(party_member_name)
    #     np.set_feature(NLG::Feature::NUMBER, NLG::NumberAgreement::PLURAL)
    #     phrase.add_front_modifier( np ) # cue phrase
    #     NLG.realizer.setCommaSepCuephrase(true)
    #   end

    #   @exhortation =       NLG.realizer.realise_sentence(phrase).gsub("the previous", "last")
    #    # Democrats, you need to hope carrot use grows from last year this year.

    #   @exhortation.gsub!(" does not ", " doesn't ") if [true, false].sample

    #   @exhortation
    # end

    # important debugging stuff

