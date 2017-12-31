require_relative '../../../parser/action_condition'
require_relative 'action'
require_relative 'matching'

class ActionCondition
  def matching
    actions.inject Matching.new do |matching, action|
      matching + action.matching
    end
  end
end
