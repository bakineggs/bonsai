require_relative '../action'

class Action::LessThan < Action
  attr_reader :left, :right, :result

  def initialize line, child_lines
    raise Parser::Error.new 'Less than action does not allow a value', line unless line == '  <:'

    child_lines.each do |child_line|
      if match = child_line.match(/^    Left: (-?\d+|(-?\d+\.\d+)|([A-Za-z][A-Za-z0-9 ]*))$/)
        raise Parser::Error.new 'Less than action must have exactly one left value', child_line if @left
        if match[2]
          @left = match[2].to_f
        elsif match[3]
          @left = [:var, match[3]]
        elsif match[1]
          @left = match[1].to_f
        end
      elsif match = child_line.match(/^    Right: (-?\d+|(-?\d+\.\d+)|([A-Za-z][A-Za-z0-9 ]*))$/)
        raise Parser::Error.new 'Less than action must have exactly one right value', child_line if @right
        if match[2]
          @right = match[2].to_f
        elsif match[3]
          @right = [:var, match[3]]
        elsif match[1]
          @right = match[1].to_f
        end
      elsif match = child_line.match(/^    Result: (-?\d+|(-?\d+\.\d+)|([A-Za-z][A-Za-z0-9 ]*))$/)
        raise Parser::Error.new 'Less than action must have exactly one result', child_line if @result
        if match[2]
          @result = match[2].to_f
        elsif match[3]
          @result = [:var, match[3]]
        elsif match[1]
          @result = match[1].to_f
        end
      else
        raise Parser::Error.new 'Unrecognized child of less than action', child_line
      end
    end

    raise Parser::Error.new 'Less than action requires a left value', line if @left.nil?
    raise Parser::Error.new 'Less than action requires a right value', line if @right.nil?
    raise Parser::Error.new 'Less than action requires a result', line if @result.nil?
  end
end
