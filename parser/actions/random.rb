require_relative '../action'

class Action::Random < Action
  attr_reader :variable

  def initialize line, child_lines
    raise Parser::Error.new 'Random action requires a variable', line unless line =~ /^  Random: ([A-Za-z][A-Za-z0-9 ]*)$/
    raise Parser::Error.new 'Random action does not allow children', child_lines.first unless child_lines.empty?

    @variable = $~[1]
  end
end
