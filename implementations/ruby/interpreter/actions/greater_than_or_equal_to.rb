class Action::GreaterThanOrEqualTo
  def matching
    Matching.new restriction: [:>=, left, right, result]
  end
end
