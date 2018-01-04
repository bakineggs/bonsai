class Action::Addition
  def matching
    Matching.new restriction: [:add, *addends, sum]
  end
end
