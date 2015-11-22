require_relative 'compiler/compiler'
require_relative '../../parser/parser'

if ARGV.length != 2
  $stderr.puts 'Usage: ruby compile.rb <source file> <target language>'
  exit 1
end

begin
  puts Compiler.new(Parser.new.parse File.read ARGV[0]).compile ARGV[1]
  exit 0

rescue Errno::ENOENT
  $stderr.puts "No such file #{ARGV[0]}"

rescue IOError
  $stderr.puts "Error reading file #{ARGV[0]}"

rescue Parser::Error => e
  $stderr.puts "Parse error on line ##{e.line.line_number}: #{e.message}"
  $stderr.puts "Line #{e.line.line_number}: #{e.line}"

rescue Compiler::Error => e
  $stderr.puts "Compile error: #{e.message}"

end

exit 1
