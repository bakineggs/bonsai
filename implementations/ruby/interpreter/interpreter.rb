require_relative '../../../parser/rule'
require_relative '../../../parser/condition'
require_relative 'node'
require_relative 'rule'
require_relative 'condition'

class Interpreter
  def initialize rules
    @rules = rules
    @tree = Node.new nil, [Node.new('^', [], false, nil)], false, nil
  end

  def run
    nodes_to_visit = NodeQueue.new
    nodes_to_visit.enqueue [0, @tree]

    until nodes_to_visit.empty?
      depth, node = nodes_to_visit.dequeue

      if @rules.any? {|rule| rule.transform node}
        nodes_to_visit.enqueue *node.descendants.map {|ddepth, _, dnode| [depth + ddepth, dnode]}
      end
    end

    root = @tree.children.find {|node| node.label == '^'}
    root.children.map(&:to_s).reject(&:empty?).join "\n"
  end

  class NodeQueue
    def initialize
      @levels = []
    end

    def enqueue *nodes
      nodes.each do |depth, node|
        @levels.push [] while @levels.length <= depth
        @levels[depth].push node
      end
    end

    def dequeue
      (0...@levels.length).to_a.reverse.each do |depth|
        return [depth, @levels[depth].pop] unless @levels[depth].empty?
      end
      raise 'Tried to dequeue from an empty NodeQueue'
    end

    def empty?
      @levels.all? &:empty?
    end
  end
end
