require 'tempfile'
require File.dirname(__FILE__) + '/../language_spec'
require File.dirname(__FILE__) + '/../../compiler/compiler'

describe Compiler do
  def run_program options
    options.each do |_, value|
      depth = value.match(/^ */)[0].length
      value.strip!
      value.gsub! /^ {#{depth}}/, ''
    end

    raise "Started: is reserved" if options[:rules].match /^ *[!+-]?Started:/
    raise "Started: is reserved" if options[:start_state].match /^ *[!+-]?Started:/

    header = options.delete :header

    start_state = options[:start_state].gsub(/^([^ ])/, '+\1').gsub /^(.)/, '  \1'
    rules = "^:\n  !Started:\n  +Started:\n#{start_state}\n\n#{options[:rules]}"

    source = Tempfile.new ['interpreter', '.c']
    source.puts Compiler.new.compile "#{header}\n\n#{rules}"
    source.flush

    result = {}

    interpreter = source.path.sub(/.c$/, '')
    if system "gcc -o #{interpreter} #{source.path}"
      `ulimit -t 1; #{interpreter} > #{interpreter}.stdout 2> #{interpreter}.stderr`

      result[:exit_status] = $?.exitstatus
      result[:stdout] = File.read "#{interpreter}.stdout"
      result[:stderr] = File.read("#{interpreter}.stderr").gsub(/^Started:\n/, '')

      if end_state = result[:stderr].split("No rules to apply!\n")[1]
        result[:end_state] = parse_state end_state
      end

      File.delete interpreter
      File.delete "#{interpreter}.stdout"
      File.delete "#{interpreter}.stderr"
    else
      result[:gcc_error] = true
    end

    source.close
    result
  end

  it_should_behave_like 'an okk implementation'
end
