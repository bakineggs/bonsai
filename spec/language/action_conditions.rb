require_relative 'actions/addition'
require_relative 'actions/subtraction'
require_relative 'actions/multiplication'
require_relative 'actions/division'
require_relative 'actions/less_than'
require_relative 'actions/greater_than'
require_relative 'actions/less_than_or_equal_to'
require_relative 'actions/greater_than_or_equal_to'

RSpec.shared_examples 'action conditions' do
  include_examples 'addition action'
  include_examples 'subtraction action'
  include_examples 'multiplication action'
  include_examples 'division action'
  include_examples 'less than action'
  include_examples 'greater than action'
  include_examples 'less than or equal to action'
  include_examples 'greater than or equal to action'
end
