class Outputter
  @@outputters = {}

  def self.[](target_language)
    @@outputters[target_language.downcase]
  end

  def initialize graph
    @graph = graph
  end
end
