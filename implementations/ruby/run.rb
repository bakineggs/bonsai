require File.dirname(__FILE__) + '/interpreter/interpreter'
require File.dirname(__FILE__) + '/../../parser/parser'

begin
  puts Interpreter.new(Parser.new.parse_program File.read ARGV[0]).run
  exit 0

rescue Errno::ENOENT
  $stderr.puts "No such file #{ARGV[0]}"

rescue IOError
  $stderr.puts "Error reading file #{ARGV[0]}"

rescue Parser::Error => e
  $stderr.puts "Parse error on line ##{e.line.line_number}: #{e.message}"
  $stderr.puts "Line #{e.line.line_number}: #{e.line}"

end

exit 1
