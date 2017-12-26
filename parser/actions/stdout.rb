require_relative '../action'

class Action::Stdout < Action
  attr_reader :values

  def initialize line, child_lines
    raise Parser::Error.new 'Stdout action does not allow a value', line unless line == '  Stdout::'

    @values = []
    child_lines.each do |child_line|
      if match = child_line.match(/^    Value:(\*?) (-?\d+|(-?\d+\.\d+)|"(.*)"|([A-Za-z][A-Za-z0-9 ]*)|\[([A-Za-z][A-Za-z0-9 ]*)\])$/)
        if match[3]
          raise Parser::Error.new 'Stdout action can not have multiple values with a constant value', child_line unless match[1].empty?
          @values.push match[3].to_f
        elsif match[4]
          raise Parser::Error.new 'Stdout action can not have multiple values with a constant value', child_line unless match[1].empty?
          @values.push match[4]
        elsif match[5]
          raise Parser::Error.new 'Stdout action can not have multiple values with a variable that matches one node', child_line unless match[1].empty?
          @values.push [:var, match[5]]
        elsif match[6]
          raise Parser::Error.new 'Stdout action can not have a single value with a variable that matches multiple nodes', child_line if match[1].empty?
          @values.push [:multivar, match[6]]
        elsif match[2]
          raise Parser::Error.new 'Stdout action can not have multiple values with a constant value', child_line unless match[1].empty?
          @values.push match[2].to_i
        end
      else
        raise Parser::Error.new 'Unrecognized child of stdout action', child_line
      end
    end

    raise Parser::Error.new 'Stdout action requires one or more values', line if @values.empty?
  end
end
