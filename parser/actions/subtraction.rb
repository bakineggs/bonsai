require_relative '../action'

class Action::Subtraction < Action
  attr_reader :minuend, :subtrahends, :difference

  def initialize line, child_lines
    raise Parser::Error.new 'Subtraction action does not allow a value', line unless line == '  -:'

    @subtrahends = []
    child_lines.each do |child_line|
      if match = child_line.match(/^    Minuend: (-?\d+|(-?\d+\.\d+)|([A-Za-z][A-Za-z0-9 ]*))$/)
        raise Parser::Error.new 'Subtraction action must have exactly one minuend', child_line if @minuend
        if match[2]
          @minuend = match[2].to_f
        elsif match[3]
          @minuend = [:var, match[3]]
        elsif match[1]
          @minuend = match[1].to_f
        end
      elsif match = child_line.match(/^    Subtrahend:(\*?) (-?\d+|(-?\d+\.\d+)|([A-Za-z][A-Za-z0-9 ]*)|\[([A-Za-z][A-Za-z0-9 ]*)\])$/)
        if match[3]
          raise Parser::Error.new 'Subtraction action can not have multiple subtrahends with a constant value', child_line unless match[1].empty?
          @subtrahends.push match[3].to_f
        elsif match[4]
          raise Parser::Error.new 'Subtraction action can not have multiple subtrahends with a variable that matches one node', child_line unless match[1].empty?
          @subtrahends.push [:var, match[4]]
        elsif match[5]
          raise Parser::Error.new 'Subtraction action can not have a single subtrahend with a variable that matches multiple nodes', child_line if match[1].empty?
          @subtrahends.push [:multivar, match[5]]
        elsif match[2]
          raise Parser::Error.new 'Subtraction action can not have multiple subtrahends with a constant value', child_line unless match[1].empty?
          @subtrahends.push match[2].to_i
        end
      elsif match = child_line.match(/^    Difference: (-?\d+|(-?\d+\.\d+)|([A-Za-z][A-Za-z0-9 ]*))$/)
        raise Parser::Error.new 'Subtraction action must have exactly one difference', child_line if @difference
        if match[2]
          @difference = match[2].to_f
        elsif match[3]
          @difference = [:var, match[3]]
        elsif match[1]
          @difference = match[1].to_f
        end
      else
        raise Parser::Error.new 'Unrecognized child of subtraction action', child_line
      end
    end

    raise Parser::Error.new 'Subtraction action requires a minuend', line if @minuend.nil?
    raise Parser::Error.new 'Subtraction action requires one or more subtrahends', line if @subtrahends.empty?
    raise Parser::Error.new 'Subtraction action requires a difference', line if @difference.nil?
  end
end
