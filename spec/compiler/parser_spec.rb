require 'spec'
require File.dirname(__FILE__) + '/../../compiler/parser'

describe Parser do
  let(:parser) { Parser.new }

  describe '#parse_rules' do
    it 'returns an empty list of rules with an empty program' do
      parser.parse_rules("").should be_empty
    end

    it 'ignores empty lines' do
      parser.parse_rules(<<-EOS).should be_empty

      EOS
    end

    it 'ignores empty lines between rules' do
      parser.parse_rules(<<-EOS.gsub /^ {8}/, '').length.should == 2

        Foo:


        Bar:

      EOS
    end

    it 'ignores comments' do
      parser.parse_rules(<<-EOS.gsub /^ {8}/, '').length.should == 2
        Foo: # comment

        # another comment

        # yet another comment
        Bar:
      EOS
    end
  end

  describe '#parse_rule' do
  end

  describe '#parse_condition' do
  end
end
