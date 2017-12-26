class Action
  def initialize line, child_lines; raise NotImplementedError end
end

Dir[File.join File.dirname(__FILE__), 'actions', '*'].each do |file|
  require_relative file
end

class Action
  TYPES = {
    '+' => Addition,
    '-' => Subtraction,
    '*' => Multiplication,
    '/' => Division,
    '<' => LessThan,
    '>' => GreaterThan,
    '<=' => LessThanOrEqualTo,
    '>=' => GreaterThanOrEqualTo,
    'Random' => Random,
    'Stdin' => Stdin,
    'Stdout:' => Stdout,
  }

  TYPES.values.each do |type|
    raise "#{type} is not an Action" unless type < Action
  end
end
