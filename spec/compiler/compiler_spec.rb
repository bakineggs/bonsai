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

    compiled = Compiler.new.compile "#{header}\n\n#{rules}"
    result = {}

    begin
      source = Tempfile.new ['interpreter', '.c']
      source.write compiled
      source.flush

      interpreter = source.path.sub(/.c$/, '')
      if system "gcc -o #{interpreter} #{source.path} > #{interpreter}.gcc.stdout 2> #{interpreter}.gcc.stderr"
        system "sh -c 'ulimit -t 1; #{interpreter} > #{interpreter}.stdout 2> #{interpreter}.stderr' 2> #{interpreter}.sh.stderr"

        result[:exit_status] = $?.exitstatus
        result[:stdout] = File.read "#{interpreter}.stdout"
        result[:stderr] = File.read("#{interpreter}.stderr").gsub(/^Started:\n/, '')
        result[:shell_stderr] = File.read "#{interpreter}.sh.stderr"

        if result[:stderr].include? "No rules to apply!"
          result[:end_state] = parse_state(result[:stderr].split("No rules to apply!\n")[1] || "")
        end

      else
        result[:compile_error] = true
        result[:gcc_stdout] = File.read "#{interpreter}.gcc.stdout"
        result[:gcc_stderr] = File.read "#{interpreter}.gcc.stderr"
      end

      result

    ensure
      source.close
      File.delete "#{interpreter}.gcc.stdout"
      File.delete "#{interpreter}.gcc.stderr"

      unless result[:compile_error]
        File.delete interpreter
        File.delete "#{interpreter}.stdout"
        File.delete "#{interpreter}.stderr"
        File.delete "#{interpreter}.sh.stderr"
      end
    end
  end

  it_should_behave_like 'a Bonsai implementation'

  it 'includes the source code of any rule in the generated interpreter' do
    source = Compiler.new.compile <<-EOS.gsub(/^ {6}/, '')
      Foo:
        Bar:

      Baz:
    EOS

    ['Match\* rule_\d+_matches', 'bool transform_rule_\d+'].each do |function|
      [
        '\1  Foo: \(line 1\)\n\1    Bar: \(line 2\)',
        '\1    Bar: \(line 2\)',
        '\1  Baz: \(line 4\)'
      ].each do |definition|
        source.should =~ /^( *)\/\*\n#{definition}\n\1\*\/\n *#{function}/
      end
    end
  end
end
