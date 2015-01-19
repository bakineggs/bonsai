RSpec.shared_examples 'matching ordered rules' do
  _it 'does not match an ordered rule with unordered children', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo:

    ^:
      Foo::
      !Matched:
      +Matched:
  EOR
    Foo:
  EOS

  _it 'matches a 0-condition ordered rule with empty ordered children', <<-EOR, <<-EOS
    ^:
      !Foo::
      +Foo::

    ^:
      Foo::
      !Matched:
      +Matched:
  EOR
    Foo::
    Matched:
  EOS

  _it 'matches a 0-condition ordered rule with non-empty ordered children', <<-EOR, <<-EOS
    ^:
      !Foo::
      +Foo::
        Bar:

    ^:
      Foo::
      !Matched:
      +Matched:
  EOR
    Foo::
      Bar:
    Matched:
  EOS

  _it 'matches a 0-condition ordered rule that must match all nodes with empty ordered children', <<-EOR, <<-EOS
    ^:
      !Foo::
      +Foo::

    ^:
      Foo::=
      !Matched:
      +Matched:
  EOR
    Foo::
    Matched:
  EOS

  _it 'does not match a 0-condition ordered rule that must match all nodes with non-empty ordered children', <<-EOR, <<-EOS
    ^:
      !Foo::
      +Foo::
        Bar:

    ^:
      Foo::=
      !Matched:
      +Matched:
  EOR
    Foo::
      Bar:
  EOS

  _it 'matches an ordered rule with ordered children that match in order', <<-EOR, <<-EOS
    ^:
      !Foo::
      +Foo::
        Bar:
        Baz:

    ^:
      Foo::
        Bar:
        Baz:
      !Matched:
      +Matched:
  EOR
    Foo::
      Bar:
      Baz:
    Matched:
  EOS

  _it 'does not match an ordered rule with ordered children that match out of order', <<-EOR, <<-EOS
    ^:
      !Foo::
      +Foo::
        Bar:
        Baz:

    ^:
      Foo::
        Baz:
        Bar:
      !Matched:
      +Matched:
  EOR
    Foo::
      Bar:
      Baz:
  EOS
end
