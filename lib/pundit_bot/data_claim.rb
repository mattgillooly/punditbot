module PunditBot
  class DataClaim
    attr_reader :condition, :year_buffer, :name
    attr_accessor :template
    def initialize(condition, template, name, year_buffer = nil)
      @template = template
      @name = name
      raise ArgumentError, "DataClaim condition is not callable" unless condition.respond_to? :call
      @condition = condition
      @year_buffer = year_buffer || 0
    end
  end
end
