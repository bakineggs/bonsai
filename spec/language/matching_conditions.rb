RSpec.shared_examples 'matching conditions' do
  _it 'matches conditions with nodes with the same label and value', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: 7.3

    ^:
      Foo: 7.3
      !Matched:
      +Matched:
  EOR
    Foo: 7.3
    Matched:
  EOS

  _it 'matches conditions with nodes with the same label and a matching child rule', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo:
        Bar:

    ^:
      Foo:
        Bar:
      !Matched:
      +Matched:
  EOR
    Foo:
      Bar:
    Matched:
  EOS

  _it 'matches descendant conditions with nodes with the same label and value', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: 7.3

    ^:
      ...Foo: 7.3
      !Matched:
      +Matched:
  EOR
    Foo: 7.3
    Matched:
  EOS

  _it 'matches descendant conditions with nodes with the same label and a matching child rule', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo:
        Bar:

    ^:
      ...Foo:
        Bar:
      !Matched:
      +Matched:
  EOR
    Foo:
      Bar:
    Matched:
  EOS

  _it 'matches descendant conditions with descendant nodes with the same label and value', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo:
        Bar:
          Baz: 7.3

    ^:
      ...Baz: 7.3
      !Matched:
      +Matched:
  EOR
    Foo:
      Bar:
        Baz: 7.3
    Matched:
  EOS

  _it 'matches descendant conditions with descendant nodes with the same label and a matching child rule', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo:
        Bar:
          Baz:
            Qux:

    ^:
      ...Baz:
        Qux:
      !Matched:
      +Matched:
  EOR
    Foo:
      Bar:
        Baz:
          Qux:
    Matched:
  EOS

  _it 'does not match conditions with nodes with the same label but a different value', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: 7.3

    ^:
      Foo: 7.2
      !Matched:
      +Matched:
  EOR
    Foo: 7.3
  EOS

  _it 'does not match conditions with nodes with the same label but a non-matching child rule', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo:
        Bar:

    ^:
      Foo:
        Baz:
      !Matched:
      +Matched:
  EOR
    Foo:
      Bar:
  EOS

  _it 'does not match descendant conditions with nodes with the same label but a different value', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: 7.3

    ^:
      ...Foo: 7.2
      !Matched:
      +Matched:
  EOR
    Foo: 7.3
  EOS

  _it 'does not match descendant conditions with nodes with the same label but a non-matching child rule', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo:
        Bar:

    ^:
      ...Foo:
        Baz:
      !Matched:
      +Matched:
  EOR
    Foo:
      Bar:
  EOS

  _it 'does not match descendant conditions with descendant nodes with the same label but a different value', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo:
        Bar:
          Baz: 7.3

    ^:
      ...Baz: 7.2
      !Matched:
      +Matched:
  EOR
    Foo:
      Bar:
        Baz: 7.3
  EOS

  _it 'does not match descendant conditions with descendant nodes with the same label but a non-matching child rule', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo:
        Bar:
          Baz:
            Qux:

    ^:
      ...Baz:
        Foobar:
      !Matched:
      +Matched:
  EOR
    Foo:
      Bar:
        Baz:
          Qux:
  EOS

  _it 'does not match conditions with nodes with a differing label but the same value', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: 7.3

    ^:
      Bar: 7.3
      !Matched:
      +Matched:
  EOR
    Foo: 7.3
  EOS

  _it 'does not match conditions with nodes with a differing label but a matching child rule', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo:
        Bar:

    ^:
      Baz:
        Bar:
      !Matched:
      +Matched:
  EOR
    Foo:
      Bar:
  EOS

  _it 'does not match descendant conditions with nodes with a differing label but the same value', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: 7.3

    ^:
      ...Bar: 7.3
      !Matched:
      +Matched:
  EOR
    Foo: 7.3
  EOS

  _it 'does not match descendant conditions with nodes with a differing label but a matching child rule', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo:
        Bar:

    ^:
      ...Baz:
        Bar:
      !Matched:
      +Matched:
  EOR
    Foo:
      Bar:
  EOS

  _it 'does not match descendant conditions with descendant nodes with a differing label but the same value', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo:
        Bar:
          Baz: 7.3

    ^:
      ...Qux: 7.3
      !Matched:
      +Matched:
  EOR
    Foo:
      Bar:
        Baz: 7.3
  EOS

  _it 'does not match descendant conditions with descendant nodes with a differing label but a matching child rule', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo:
        Bar:
          Baz:
            Qux:

    ^:
      ...Foobar:
        Qux:
      !Matched:
      +Matched:
  EOR
    Foo:
      Bar:
        Baz:
          Qux:
  EOS

  _it 'does not match conditions with nodes with a differing label and value', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: 7.3

    ^:
      Bar: 7.2
      !Matched:
      +Matched:
  EOR
    Foo: 7.3
  EOS

  _it 'does not match conditions with nodes with a differing label and a non-matching child rule', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo:
        Bar:

    ^:
      Qux:
        Baz:
      !Matched:
      +Matched:
  EOR
    Foo:
      Bar:
  EOS

  _it 'does not match descendant conditions with nodes with a differing label and value', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: 7.3

    ^:
      ...Bar: 7.2
      !Matched:
      +Matched:
  EOR
    Foo: 7.3
  EOS

  _it 'does not match descendant conditions with nodes with a differing label and a non-matching child rule', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo:
        Bar:

    ^:
      ...Qux:
        Baz:
      !Matched:
      +Matched:
  EOR
    Foo:
      Bar:
  EOS

  _it 'does not match descendant conditions with descendant nodes with a differing label and value', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo:
        Bar:
          Baz: 7.3

    ^:
      ...Qux: 7.2
      !Matched:
      +Matched:
  EOR
    Foo:
      Bar:
        Baz: 7.3
  EOS

  _it 'does not match descendant conditions with descendant nodes with a differing label and a non-matching child rule', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo:
        Bar:
          Baz:
            Qux:

    ^:
      ...Foobar:
        Foobaz:
      !Matched:
      +Matched:
  EOR
    Foo:
      Bar:
        Baz:
          Qux:
  EOS
end
