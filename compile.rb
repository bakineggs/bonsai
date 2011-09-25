require 'compiler/compiler'

begin
  puts Compiler.new.compile File.read ARGV[0]
end
