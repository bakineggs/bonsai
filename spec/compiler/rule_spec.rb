require 'spec'
require File.dirname(__FILE__) + '/../../compiler/rule'

describe Rule do
  describe '#conditions_can_match_in_order?' do
    it 'allows ordered conditions to match in order'
    it 'does not allow unordered conditions to match in order'
    it 'allows top-level conditions to match in order'
  end

  describe '#conditions_can_match_out_of_order?' do
    it 'allows unordered conditions to match out of order'
    it 'does not allow ordered conditions to match out of order'
    it 'allows top-level conditions to match out of order'
  end

  describe '#conditions_can_match_ordered_nodes_out_of_order?' do
    it 'allows unordered conditions to match ordered nodes out of order'
    it 'does not allow ordered conditions to match ordered nodes out of order'
    it 'does not allow top-level conditions to match ordered nodes out of order'
  end
end
