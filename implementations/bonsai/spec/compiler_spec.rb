require_relative '../../../spec/language_spec'
require_relative '../../../parser/parser'
require_relative '../compiler/compiler'
require_relative '../../ruby/interpreter/interpreter'

RSpec.describe 'The Bonsai implementation of Bonsai' do
  def compile program
    Compiler.new.compile program
  end

  describe 'using the Ruby interpreted implementation of Bonsai' do
    def run program
      Interpreter.new(Parser.new.parse compile program).run.to_s
    end

    include_examples 'a Bonsai implementation'
  end
end
