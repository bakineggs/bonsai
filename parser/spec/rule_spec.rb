require 'spec'
require File.dirname(__FILE__) + '/../rule'
require File.dirname(__FILE__) + '/../parser'

describe Rule do
  let(:top_level_rule) { Parser.new.parse_program("Foo:\nBar::")[:rules].first }
  let(:unordered_rule) { top_level_rule.conditions[0].child_rule }
  let(:ordered_rule) { top_level_rule.conditions[1].child_rule }

  describe '#conditions_can_match_in_order?' do
    it 'allows ordered conditions to match in order' do
      ordered_rule.conditions_can_match_in_order?.should be_true
    end

    it 'does not allow unordered conditions to match in order' do
      unordered_rule.conditions_can_match_in_order?.should be_false
    end

    it 'allows top-level conditions to match in order' do
      top_level_rule.conditions_can_match_in_order?.should be_true
    end
  end

  describe '#conditions_can_match_out_of_order?' do
    it 'allows unordered conditions to match out of order' do
      unordered_rule.conditions_can_match_out_of_order?.should be_true
    end

    it 'does not allow ordered conditions to match out of order' do
      ordered_rule.conditions_can_match_out_of_order?.should be_false
    end

    it 'allows top-level conditions to match out of order' do
      top_level_rule.conditions_can_match_out_of_order?.should be_true
    end
  end

  describe '#conditions_can_match_ordered_nodes_out_of_order?' do
    it 'allows unordered conditions to match ordered nodes out of order' do
      unordered_rule.conditions_can_match_ordered_nodes_out_of_order?.should be_true
    end

    it 'does not allow ordered conditions to match ordered nodes out of order' do
      ordered_rule.conditions_can_match_ordered_nodes_out_of_order?.should be_false
    end

    it 'does not allow top-level conditions to match ordered nodes out of order' do
      top_level_rule.conditions_can_match_ordered_nodes_out_of_order?.should be_false
    end
  end
end
