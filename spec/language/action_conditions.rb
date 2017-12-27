require_relative 'actions/addition'
require_relative 'actions/subtraction'
require_relative 'actions/multiplication'
require_relative 'actions/division'

RSpec.shared_examples 'action conditions' do
  include_examples 'addition action'
  include_examples 'subtraction action'
  include_examples 'multiplication action'
  include_examples 'division action'
end
