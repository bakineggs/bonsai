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

    start_state = options[:start_state].gsub(/^([^ ])/, '+\1').gsub /^/, '  '
    rules = "^:\n  !Started:\n  +Started:\n#{start_state}\n\n#{options[:rules]}"

    source = Tempfile.new ['interpreter', '.c']
    source.puts Compiler.new.compile rules
    source.flush

    result = {}

    interpreter = source.path.sub(/.c$/, '')
    if system "gcc -o #{interpreter} #{source.path}"
      `#{interpreter} > #{interpreter}.stdout 2> #{interpreter}.stderr`

      result[:exit_status] = $?.exitstatus
      result[:stdout] = File.read "#{interpreter}.stdout"
      result[:stderr] = File.read("#{interpreter}.stderr").gsub(/^Started:\n/, '')
      result[:end_state] = []

      if end_state = result[:stderr].split("No rules to apply!\n")[1]
        result[:end_state] = parse_state end_state
      end

      File.delete interpreter
      File.delete "#{interpreter}.stdout"
      File.delete "#{interpreter}.stderr"
    end

    source.close
    result
  end

  it_should_behave_like 'an okk implementation'
end
