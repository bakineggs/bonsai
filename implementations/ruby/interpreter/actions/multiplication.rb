class Action::Multiplication
  def matching
    Matching.new restriction: [:multiply, *factors, product]
  end
end
