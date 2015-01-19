class Node
  attr_reader :label, :children, :value

  def initialize label, children, children_are_ordered, value
    @label = label
    @children = children
    @children_are_ordered = !!children_are_ordered
    @value = value

    raise 'A node must have a non-empty String label' unless @label.nil? || @label.is_a?(String) && !@label.empty?

    raise 'A node must have either children or a value' unless @children || @value
    raise 'A node can not have both children and a value' if @children && @value

    raise 'A node with a value can not have ordered children' if @value && @children_are_ordered

    raise 'A node must have an Array of Node children' unless @children.nil? || @children.is_a?(Array) && @children.all? {|child| child.is_a? Node}
    raise 'A node must have a Fixnum, Float, or String value' unless @value.nil? || [Fixnum, Float, String].any? {|t| @value.is_a? t}
  end

  def initialize_copy original
    super
    @children = original.children.map &:dup if @children
  end

  def children_are_ordered?
    !!@children_are_ordered
  end

  def descendants
    descendants = [[0, nil, self]]
    children.each do |child|
      child.descendants.each do |depth, parent, node|
        descendants.push [depth + 1, parent || self, node]
      end
    end if children
    descendants
  end

  def to_s depth = 0
    if value && value.is_a?(String)
      '  ' * depth + label + ': "' + value + '"'
    elsif value
      '  ' * depth + label + ': ' + value.to_s
    elsif children
      lines = ['  ' * depth + label + ':' + (children_are_ordered? ? ':' : '')]
      lines += children.map {|child| child.to_s depth + 1}
      lines.join "\n"
    end
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
