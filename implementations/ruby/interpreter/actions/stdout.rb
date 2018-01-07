class Action::Stdout
  def matching
    Matching.new actions: values.map {|value| lambda {|_| print value.is_a?(Array) && value.first == :var ? variable_value(value.last) : value} }
  end
end
