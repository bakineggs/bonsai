class Node
  attr_reader :label, :children, :value

  def initialize label, children, children_are_ordered, value
    raise 'Can\'t have node with children and value' if children && value
    @label = label
    @children = children
    @children_are_ordered = children_are_ordered
    @value = value
  end

  def initialize_copy original
    super
    @children = original.children.map &:dup if @children
  end

  def children_are_ordered?
    !!@children_are_ordered
  end

  def descendants
    descendants = [[0, self]]
    children.each do |child|
      child.descendants.each do |depth, node|
        descendants.push [depth + 1, node]
      end
    end if children
    descendants
  end

  def to_s depth = 0
    s = ' ' * 4 * depth + "Node:\n"
    s += ' ' * 4 * depth + "  Label: \"#{label}\"\n"
    if children
      s += ' ' * 4 * depth + "  Children:#{':' if children_are_ordered?}\n"
      children.each {|child| s += child.to_s depth + 1}
    elsif value
      if value.is_a? String
        s += ' ' * 4 * depth + "  Value: \"#{value}\"\n"
      else
        s += ' ' * 4 * depth + "  Value: #{value}\n"
      end
    end
    s
  end

  def equals_except_label? other
    if value
      value == other.value
    elsif children_are_ordered? != other.children_are_ordered?
      false
    elsif children_are_ordered?
      children == other.children
    else
      children.sort == other.children.sort
    end
  end

  include Comparable
  def <=> other
    if label != other.label
      label <=> other.label
    elsif value && other.value
      value <=> other.value
    elsif value && !other.value
      -1
    elsif !value && other.value
      1
    elsif children_are_ordered? && other.children_are_ordered?
      children <=> other.children
    elsif !children_are_ordered? && !other.children_are_ordered?
      children.sort <=> other.children.sort
    elsif children_are_ordered? && !other.children_are_ordered?
      -1
    elsif !children_are_ordered? && other.children_are_ordered?
      1
    end
  end
end
