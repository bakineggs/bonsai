class Action::Subtraction
  def matching
    Matching.new restriction: [:subtract, minuend, *subtrahends, difference]
  end
end
