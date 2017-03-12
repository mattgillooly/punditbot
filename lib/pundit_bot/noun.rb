module PunditBot
  class Noun # < String
    attr_reader :word
    def initialize(word, number)
      @word = word.is_a?(Noun) ? word.word : word
      @number = number
    end

    def number
      plural? ? :plural : :singular
    end

    def plural?
      @number != 1
    end

    def singular?
      @number == 1
    end

    # if this inherits from String, get rid of #to_s and #size
    def to_s
      "Noun: #{@word}"
    end

    def size
      word.size
    end
  end
end
