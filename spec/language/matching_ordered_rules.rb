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

  _it 'matches an ordered rule with ordered children that match in order starting in the middle', <<-EOR, <<-EOS
    ^:
      !Foo::
      +Foo::
        Bar:
        Baz:
        Qux:

    ^:
      Foo::
        Baz:
        Qux:
      !Matched:
      +Matched:
  EOR
    Foo::
      Bar:
      Baz:
      Qux:
    Matched:
  EOS

  _it 'does not match an ordered rule that must match all nodes with ordered children that match in order starting in the middle', <<-EOR, <<-EOS
    ^:
      !Foo::
      +Foo::
        Bar:
        Baz:
        Qux:

    ^:
      Foo::=
        Baz:
        Qux:
      !Matched:
      +Matched:
  EOR
    Foo::
      Bar:
      Baz:
      Qux:
  EOS

  _it 'matches a preventing condition in an ordered rule with a non-matching ordered child', <<-EOR, <<-EOS
    ^:
      !Foo::
      +Foo::
        Bar:

    ^:
      Foo::
        !Baz:
      !Matched:
      +Matched:
  EOR
    Foo::
      Bar:
    Matched:
  EOS

  _it 'matches a preventing condition in an ordered rule that must match all nodes with a non-matching ordered child', <<-EOR, <<-EOS
    ^:
      !Foo::
      +Foo::
        Bar:

    ^:
      Foo::=
        !Baz:
      !Matched:
      +Matched:
  EOR
    Foo::
      Bar:
    Matched:
  EOS

  _it 'does not match a preventing condition in an ordered rule with a matching ordered child', <<-EOR, <<-EOS
    ^:
      !Foo::
      +Foo::
        Bar:

    ^:
      Foo::
        !Bar:
      !Matched:
      +Matched:
  EOR
    Foo::
      Bar:
  EOS

  _it 'matches a preventing condition in an ordered rule with a matching and a non-matching ordered child', <<-EOR, <<-EOS
    ^:
      !Foo::
      +Foo::
        Bar:
        Baz:

    ^:
      Foo::
        !Baz:
      !Matched:
      +Matched:
  EOR
    Foo::
      Bar:
      Baz:
    Matched:
  EOS

  _it 'does not match a preventing condition in an ordered rule that must match all nodes with a matching and a non-matching ordered child', <<-EOR, <<-EOS
    ^:
      !Foo::
      +Foo::
        Bar:
        Baz:

    ^:
      Foo::=
        !Baz:
      !Matched:
      +Matched:
  EOR
    Foo::
      Bar:
      Baz:
  EOS

  _it 'matches a removing condition in an ordered rule with an in order sibling', <<-EOR, <<-EOS
    ^:
      !Foo::
      +Foo::
        Bar:
        Baz:
        Qux:

    ^:
      Foo::
        Baz:
        -Qux:
  EOR
    Foo::
      Bar:
      Baz:
  EOS

  _it 'does not match a removing condition in an ordered rule with an out of order sibling', <<-EOR, <<-EOS
    ^:
      !Foo::
      +Foo::
        Bar:
        Baz:
        Qux:

    ^:
      Foo::
        Baz:
        -Bar:
  EOR
    Foo::
      Bar:
      Baz:
      Qux:
  EOS
end
