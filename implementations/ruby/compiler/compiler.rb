require_relative 'potential_state_graph'
require_relative 'outputter'

class Compiler
  class Error < StandardError; end

  def initialize rules
    @potential_state_graph = PotentialStateGraph.new rules
  end

  def compile target_language
    begin
      require_relative "outputters/#{target_language}"
      raise Error.new "Invalid outputter for target language: #{target_language}" unless Outputter[target_language]
    rescue LoadError
      raise Error.new "Unknown target language: #{target_language}"
    end unless Outputter[target_language]

    Outputter[target_language].new(@potential_state_graph).output
  end
end
