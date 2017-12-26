require_relative '../action'

class Action::Addition < Action
  attr_reader :addends, :sum

  def initialize line, child_lines
    raise Parser::Error.new 'Addition action does not allow a value', line unless line == '  +:'

    @addends = []
    child_lines.each do |child_line|
      if match = child_line.match(/^    Addend:(\*?) (-?\d+|(-?\d+\.\d+)|([A-Za-z][A-Za-z0-9 ]*)|\[([A-Za-z][A-Za-z0-9 ]*)\])$/)
        if match[3]
          raise Parser::Error.new 'Addition action can not have multiple addends with a constant value', child_line unless match[1].empty?
          @addends.push match[3].to_f
        elsif match[4]
          raise Parser::Error.new 'Addition action can not have multiple addends with a variable that matches one node', child_line unless match[1].empty?
          @addends.push [:var, match[4]]
        elsif match[5]
          raise Parser::Error.new 'Addition action can not have a single addend with a variable that matches multiple nodes', child_line if match[1].empty?
          @addends.push [:multivar, match[5]]
        elsif match[2]
          raise Parser::Error.new 'Addition action can not have multiple addends with a constant value', child_line unless match[1].empty?
          @addends.push match[2].to_i
        end
      elsif match = child_line.match(/^    Sum: (-?\d+|(-?\d+\.\d+)|([A-Za-z][A-Za-z0-9 ]*))$/)
        raise Parser::Error.new 'Addition action must have exactly one sum', child_line if @sum
        if match[2]
          @sum = match[2].to_f
        elsif match[3]
          @sum = [:var, match[3]]
        elsif match[1]
          @sum = match[1].to_f
        end
      else
        raise Parser::Error.new 'Unrecognized child of addition action', child_line
      end
    end

    raise Parser::Error.new 'Addition action requires one or more addends', line if @addends.empty?
    raise Parser::Error.new 'Addition action requires a sum', line if @sum.nil?
  end
end
