class Action::LessThan
  def matching
    Matching.new restriction: [:<, left, right, result]
  end
end
