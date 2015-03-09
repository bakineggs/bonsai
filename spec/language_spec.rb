require_relative 'language/visiting_nodes'
require_relative 'language/matching_conditions'
require_relative 'language/preventing_matches'
require_relative 'language/creating_nodes'
require_relative 'language/removing_nodes'
require_relative 'language/matching_ordered_rules'

RSpec.shared_examples 'a Bonsai implementation' do
  def self._it description, program, end_state
    program = program.gsub /^#{program.match(/^ */)[0]}/, ''
    end_state = end_state.gsub /^#{end_state.match(/^ */)[0]}/, ''
    it description do
      expect(print parse run program).to eq print parse end_state
    end
  end

  include_examples 'visiting nodes'
  include_examples 'matching conditions'
  include_examples 'preventing matches'
  include_examples 'removing nodes'
  include_examples 'matching ordered rules'

  def parse state_str, needs_sort = true
    lines = state_str.split "\n"
    state = []

    return state if lines.empty?
    depth = lines.first.match(/^ */)[0].length

    raise 'A node can not be in between levels' if depth % 2 == 1

    parent = nil
    child_lines = []
    lines.each do |line|
      if child_lines.empty? && line.match(/^ {#{depth}}   /)
        raise 'A node can not be more than one level below its parent'
      elsif line.match /^ {#{depth}}  /
        child_lines.push line
      elsif match = line.match(/^ {#{depth}}(\^|[A-Za-z0-9 ]+):(:)?( (-?\d+|(-?\d+\.\d+)|"(.*)"))?$/)
        if parent
          if parent[:value] && !child_lines.empty?
            raise 'A node with a value can not have children'
          elsif !parent[:value]
            parent[:children] = parse child_lines.join("\n"), !parent[:ordered]
          end
          state.push parent
        end

        parent = {:label => match[1], :ordered => match[2] == ':'}
        child_lines = []
        if match[6]
          parent[:value] = match[6]
        elsif match[5]
          parent[:value] = match[5].to_f
        elsif match[4]
          parent[:value] = match[4].to_i
        end
      else
        raise 'Could not parse state'
      end
    end

    if parent
      if parent[:value] && !child_lines.empty?
        raise 'A node with a value can not have children'
      elsif !parent[:value]
        parent[:children] = parse child_lines.join("\n"), !parent[:ordered]
      end
      state.push parent
    end

    if needs_sort
      compare = lambda do |node|
        [node[:label], node[:value].class.name, node[:value], node[:ordered], node[:children] && node[:children].map {|child| compare.call child}]
      end
      state.sort_by! &compare
    end

    state
  end

  def print state, depth = 0
    lines = []
    state.each do |node|
      if node[:value] && node[:value].is_a?(String)
        lines.push "#{'  ' * depth}#{node[:label]}: \"#{node[:value]}\""
      elsif node[:value]
        lines.push "#{'  ' * depth}#{node[:label]}: #{node[:value]}"
      elsif node[:children]
        lines.push "#{'  ' * depth}#{node[:label]}:#{':' if node[:ordered]}"
        line = print node[:children], depth + 1
        lines.push line unless line == ''
      end
    end
    lines.join "\n"
  end
end
