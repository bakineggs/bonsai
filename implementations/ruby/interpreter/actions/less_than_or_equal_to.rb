class Action::LessThanOrEqualTo
  def matching
    Matching.new restriction: [:<=, left, right, result]
  end
end
