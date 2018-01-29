require_relative '../action'

class Action::Exit < Action
  attr_reader :status

  def initialize line, child_lines
    raise Parser::Error.new 'Exit action requires a status', line unless line =~ /^  Exit: ([0-9]*)$/
    raise Parser::Error.new 'Exit action does not allow children', child_lines.first unless child_lines.empty?

    @status = $~[1].to_i
  end
end
