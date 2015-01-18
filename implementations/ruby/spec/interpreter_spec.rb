require_relative '../../../spec/language_spec'
require_relative '../../../parser/parser'
require_relative '../interpreter/interpreter'

RSpec.describe 'The Ruby implementation of Bonsai' do
  def run program
    Interpreter.new(Parser.new.parse program).run.to_s
  end

  include_examples 'a Bonsai implementation'
end
