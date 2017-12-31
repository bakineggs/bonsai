RSpec.shared_examples 'random action' do
  # TODO: better testing: (see https://www.random.org/analysis/)
  it 'supplies values fitting a uniform distribution between 0 and 1' do
    numbers = 10000.times.map do
      parse(run "^:\n  !Number:\n  +Number: X\n$:\n  Random: X")[0][:value]
    end
    (1...100).each do |group|
      members = numbers.count {|number| number >= group / 100.0 && number < (group + 1) / 100.0}
      fail "Group #{group} had #{members} members" if members < 50 || members > 150
    end
  end
end
