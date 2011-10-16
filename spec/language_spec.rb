shared_examples_for 'an okk implementation' do
  it 'errors out when no rules match' do
    result = run_program :rules => "Foo:", :start_state => "Bar:"
    result[:exit_status].should == 1
    result[:stdout].should == ""
    result[:stderr].should == "No rules to apply!\nBar:"
  end

  it 'errors out when no rules make a change' do
    result = run_program :rules => "Foo:", :start_state => "Foo:"
    result[:exit_status].should == 1
    result[:stdout].should == ""
    result[:stderr].should == "No rules to apply!\nFoo:"
  end

  it 'executes code of a matched rule' do
    result = run_program :rules => "Foo: < exit(0);", :start_state => "Foo:"
    result[:exit_status].should == 0
    result[:stdout].should == ""
    result[:stderr].should == ""
  end

  describe 'creating nodes'
  describe 'removing nodes'
  describe 'preventing a match'
  describe 'ordered children'
  describe 'matching multiple nodes'
  describe 'node values'
end
