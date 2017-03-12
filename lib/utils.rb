def dupnil(obj)
  obj.nil? ? nil : obj.dup
end

def with(instance, &block) # ♫ gimme some syntactic sugar, I am your neighbor ♫
  instance.instance_eval(&block)
  instance
end

class JeremyMessedUpError < StandardError; end

class Array
  def rephrase
    sample
  end
end

class Hash
  def compact!
    each do |k, v|
      delete(k) if v.nil?
    end
  end

  def compact
    z = self.dup
    z.compact!
    z
  end

  def self.recursive
    new { |hash, key| hash[key] = recursive }
  end
end
