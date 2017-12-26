require_relative '../action'

class Action::Division < Action
  attr_reader :dividend, :divisor, :quotient

  def initialize line, child_lines
    raise Parser::Error.new 'Division action does not allow a value', line unless line == '  /:'

    child_lines.each do |child_line|
      if match = child_line.match(/^    Dividend: (-?\d+|(-?\d+\.\d+)|([A-Za-z][A-Za-z0-9 ]*))$/)
        raise Parser::Error.new 'Division action must have exactly one dividend', child_line if @dividend
        if match[2]
          @dividend = match[2].to_f
        elsif match[3]
          @dividend = [:var, match[3]]
        elsif match[1]
          @dividend = match[1].to_f
        end
      elsif match = child_line.match(/^    Divisor: (-?\d+|(-?\d+\.\d+)|([A-Za-z][A-Za-z0-9 ]*))$/)
        raise Parser::Error.new 'Division action must have exactly one divisor', child_line if @divisor
        if match[2]
          @divisor = match[2].to_f
        elsif match[3]
          @divisor = [:var, match[3]]
        elsif match[1]
          @divisor = match[1].to_f
        end
      elsif match = child_line.match(/^    Quotient: (-?\d+|(-?\d+\.\d+)|([A-Za-z][A-Za-z0-9 ]*))$/)
        raise Parser::Error.new 'Division action must have exactly one quotient', child_line if @quotient
        if match[2]
          @quotient = match[2].to_f
        elsif match[3]
          @quotient = [:var, match[3]]
        elsif match[1]
          @quotient = match[1].to_f
        end
      else
        raise Parser::Error.new 'Unrecognized child of division action', child_line
      end
    end

    raise Parser::Error.new 'Division action requires a dividend', line if @dividend.nil?
    raise Parser::Error.new 'Division action requires a divisor', line if @divisor.nil?
    raise Parser::Error.new 'Division action requires a quotient', line if @quotient.nil?
  end
end
