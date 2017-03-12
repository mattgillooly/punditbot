require_relative "./lib/pundit_bot.rb"
if __FILE__ == $0
  while 1
    prediction = PunditBot.generate_prediction
    break unless prediction.nil? || prediction.to_s.nil?
  end

  if prediction.to_s.size > 140 && prediction.to_s[-1] == "."
    prediction.to_s = prediction.to_s[0...-1]
  end

  puts prediction.to_s
end
