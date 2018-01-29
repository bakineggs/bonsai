class Action::Exit
  def matching
    status = @status
    Matching.new actions: [lambda {|_| exit status}]
  end
end
