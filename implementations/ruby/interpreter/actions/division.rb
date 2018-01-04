class Action::Division
  def matching
    Matching.new restriction: [:divide, dividend, divisor, quotient]
  end
end
