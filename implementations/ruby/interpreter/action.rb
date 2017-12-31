Dir[File.join File.dirname(__FILE__), 'actions', '*'].each do |file|
  require_relative file
end
