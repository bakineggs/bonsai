require File.dirname(__FILE__) + '/../../../parser/rule'
require File.dirname(__FILE__) + '/../../../parser/condition'
require File.dirname(__FILE__) + '/node'
require File.dirname(__FILE__) + '/rule'

class Interpreter
  def initialize rules
    @rules = rules
    @tree = Node.new '^', [], false, nil
  end

  def run
    nodes_to_visit = NodeQueue.new
    nodes_to_visit.enqueue [0, @tree]

    until nodes_to_visit.empty?
      depth, node = nodes_to_visit.dequeue

      if @rules.any? {|rule| rule.transform node}
        nodes_to_visit.enqueue *node.descendants.map {|ddepth, dnode| [depth + ddepth, dnode]}
      end
    end

    @tree
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
