class Outputter::Ruby < Outputter
  @@outputters['ruby'] = self

  def output
    'puts "HelloWorld:"' # TODO
  end
end
