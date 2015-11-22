require_relative '../../../spec/language_spec'
require_relative '../../../parser/parser'
require_relative '../compiler/compiler'

RSpec.describe 'The Ruby implementation of Bonsai' do
  def run program
    ruby_code = Compiler.new(Parser.new.parse program).compile 'ruby'
    Tempfile.create 'bonsai_test' do |file|
      file.write ruby_code
      file.flush
      `ruby #{file.path}`
    end
  end

  include_examples 'a Bonsai implementation'
end
