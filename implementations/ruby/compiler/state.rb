require_relative 'node'
require_relative 'rule'

class State
  attr_reader :rules, :tree

  @@trees = {}
  @@proceeding = {}

  def initialize rules, tree = Node.new
    @rules = rules
    (@tree = @@trees[tree.fingerprint] ||= tree).freeze
  end

  def proceeding
    @proceeding or raise 'State#proceeding can not be used before State#expand!'
  end

  def expand!
    raise 'State#expand! called unncessarily' unless @proceeding.nil?

    unless @proceeding ||= @@proceeding[fingerprint]
      @proceeding = @@proceeding[fingerprint] = {}
      @rules.each do |rule|
        rule.proceeding_states(self).each do |state|
          unless @proceeding.has_key? state.fingerprint
            @proceeding[state.fingerprint] = state
            state.expand!
            state.freeze
          end
        end
      end
      @proceeding.freeze
    end
  end

  def minimize!
    # TODO
  end

  def fingerprint
    return @fingerprint if @fingerprint
    unless @rules.respond_to? :fingerprint
      @rules.define_singleton_method :fingerprint do
        @fingerprint ||= map(&:fingerprint).sort.join.hash
      end
    end
    @fingerprint = [@rules, @tree].map(&:fingerprint).join.hash
  end
end
