require_relative 'action'
require_relative 'parser'

class ActionCondition
  attr_reader :actions

  def initialize lines
    action_line = lines.shift
    child_lines = []

    @actions = []
    lines.each do |line|
      if line.match /^    /
        child_lines.push line
        next
      elsif line.match /^   /
        raise Parser::Error.new 'Conditions can not be in between levels', line
      end

      @actions.push parse_action action_line, child_lines
      action_line = line
      child_lines = []
    end

    @actions.push parse_action action_line, child_lines
  end

  private

  def parse_action line, child_lines
    raise Parser::Error.new "Unrecognized action: #{line.sub /^  ([^:]*:?):.*$/, '\1'}", line unless type = Action::TYPES[line.sub /^  ([^:]*:?):.*$/, '\1']
    type.new line, child_lines
  end
end
