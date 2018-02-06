require_relative '../../../parser/rule'

class Rule
  def definitely_enables? rule
    false # TODO
  end

  def possibly_enables? rule
    true # TODO
  end

  def definitely_disables? rule
    false # TODO
  end

  def possibly_disables? rule
    true # TODO
  end

  def definitely_matches? state
    false # TODO
  end

  def definitely_does_not_match? state
    false #TODO
  end

  def transform state
    [] # TODO
  end
end
