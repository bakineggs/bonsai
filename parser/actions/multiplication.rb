require_relative '../action'

class Action::Multiplication < Action
  attr_reader :factors, :product

  def initialize line, child_lines
    raise Parser::Error.new 'Multiplication action does not allow a value', line unless line == '  *:'

    @factors = []
    child_lines.each do |child_line|
      if match = child_line.match(/^    Factor:(\*?) (-?\d+|(-?\d+\.\d+)|([A-Za-z][A-Za-z0-9 ]*)|\[([A-Za-z][A-Za-z0-9 ]*)\])$/)
        if match[3]
          raise Parser::Error.new 'Multiplication action can not have multiple factors with a constant value', child_line unless match[1].empty?
          @factors.push match[3].to_f
        elsif match[4]
          raise Parser::Error.new 'Multiplication action can not have multiple factors with a variable that matches one node', child_line unless match[1].empty?
          @factors.push [:var, match[4]]
        elsif match[5]
          raise Parser::Error.new 'Multiplication action can not have a single factor with a variable that matches multiple nodes', child_line if match[1].empty?
          @factors.push [:multivar, match[5]]
        elsif match[2]
          raise Parser::Error.new 'Multiplication action can not have multiple factors with a constant value', child_line unless match[1].empty?
          @factors.push match[2].to_i
        end
      elsif match = child_line.match(/^    Product: (-?\d+|(-?\d+\.\d+)|([A-Za-z][A-Za-z0-9 ]*))$/)
        raise Parser::Error.new 'Multiplication action must have exactly one product', child_line if @product
        if match[2]
          @product = match[2].to_f
        elsif match[3]
          @product = [:var, match[3]]
        elsif match[1]
          @product = match[1].to_f
        end
      else
        raise Parser::Error.new 'Unrecognized child of multiplication action', child_line
      end
    end

    raise Parser::Error.new 'Multiplication action requires one or more factors', line if @factors.empty?
    raise Parser::Error.new 'Multiplication action requires a product', line if @product.nil?
  end
end
