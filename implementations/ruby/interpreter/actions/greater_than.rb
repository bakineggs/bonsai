class Action::GreaterThan
  def matching
    Matching.new restriction: [:>, left, right, result]
  end
end
