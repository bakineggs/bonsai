require_relative 'state'

class Compiler
  class Error < StandardError; end

  def initialize rules
    @rules = rules
  end

  def compile target_language
    begin
      require_relative "outputters/#{target_language}"
    rescue LoadError
      raise Error.new "Unknown target language: #{target_language}"
    end

    state = State.new @rules
    state.expand!
    state.minimize!

    Outputter.new(state).output
  end
end
