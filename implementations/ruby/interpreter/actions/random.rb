class Action::Random
  def matching
    Matching.new restriction: [:eq, variable, Node.new('Random', nil, nil, rand), false]
  end
end
