RSpec.shared_examples 'preventing matches' do
  _it 'matches preventing conditions with nodes with the same label and value', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Ready:
      +Foo: 7.3

    ^:
      Ready:
      !Foo: 7.3
      !Matched:
      +Matched:
  EOR
    Ready:
    Foo: 7.3
  EOS

  _it 'matches preventing conditions with nodes with the same label and a matching child rule', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Ready:
      +Foo:
        Bar:

    ^:
      Ready:
      !Foo:
        Bar:
      !Matched:
      +Matched:
  EOR
    Ready:
    Foo:
      Bar:
  EOS

  _it 'matches descendant preventing conditions with nodes with the same label and value', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Ready:
      +Foo: 7.3

    ^:
      Ready:
      !...Foo: 7.3
      !Matched:
      +Matched:
  EOR
    Ready:
    Foo: 7.3
  EOS

  _it 'matches descendant preventing conditions with nodes with the same label and a matching child rule', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Ready:
      +Foo:
        Bar:

    ^:
      Ready:
      !...Foo:
        Bar:
      !Matched:
      +Matched:
  EOR
    Ready:
    Foo:
      Bar:
  EOS

  _it 'matches descendant preventing conditions with descendant nodes with the same label and value', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Ready:
      +Foo:
        Bar:
          Baz: 7.3

    ^:
      Ready:
      !...Baz: 7.3
      !Matched:
      +Matched:
  EOR
    Ready:
    Foo:
      Bar:
        Baz: 7.3
  EOS

  _it 'matches descendant preventing conditions with descendant nodes with the same label and a matching child rule', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Ready:
      +Foo:
        Bar:
          Baz:
            Qux:

    ^:
      Ready:
      !...Baz:
        Qux:
      !Matched:
      +Matched:
  EOR
    Ready:
    Foo:
      Bar:
        Baz:
          Qux:
  EOS

  _it 'does not match preventing conditions with nodes with the same label but a different value', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Ready:
      +Foo: 7.3

    ^:
      Ready:
      !Foo: 7.2
      !Matched:
      +Matched:
  EOR
    Ready:
    Foo: 7.3
    Matched:
  EOS

  _it 'does not match preventing conditions with nodes with the same label but a non-matching child rule', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Ready:
      +Foo:
        Bar:

    ^:
      Ready:
      !Foo:
        Baz:
      !Matched:
      +Matched:
  EOR
    Ready:
    Foo:
      Bar:
    Matched:
  EOS

  _it 'does not match descendant preventing conditions with nodes with the same label but a different value', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Ready:
      +Foo: 7.3

    ^:
      Ready:
      !...Foo: 7.2
      !Matched:
      +Matched:
  EOR
    Ready:
    Foo: 7.3
    Matched:
  EOS

  _it 'does not match descendant preventing conditions with nodes with the same label but a non-matching child rule', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Ready:
      +Foo:
        Bar:

    ^:
      Ready:
      !...Foo:
        Baz:
      !Matched:
      +Matched:
  EOR
    Ready:
    Foo:
      Bar:
    Matched:
  EOS

  _it 'does not match descendant preventing conditions with descendant nodes with the same label but a different value', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Ready:
      +Foo:
        Bar:
          Baz: 7.3

    ^:
      Ready:
      !...Baz: 7.2
      !Matched:
      +Matched:
  EOR
    Ready:
    Foo:
      Bar:
        Baz: 7.3
    Matched:
  EOS

  _it 'does not match descendant preventing conditions with descendant nodes with the same label but a non-matching child rule', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Ready:
      +Foo:
        Bar:
          Baz:
            Qux:

    ^:
      Ready:
      !...Baz:
        Foobar:
      !Matched:
      +Matched:
  EOR
    Ready:
    Foo:
      Bar:
        Baz:
          Qux:
    Matched:
  EOS

  _it 'does not match preventing conditions with nodes with a differing label but the same value', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Ready:
      +Foo: 7.3

    ^:
      Ready:
      !Bar: 7.3
      !Matched:
      +Matched:
  EOR
    Ready:
    Foo: 7.3
    Matched:
  EOS

  _it 'does not match preventing conditions with nodes with a differing label but a matching child rule', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Ready:
      +Foo:
        Bar:

    ^:
      Ready:
      !Baz:
        Bar:
      !Matched:
      +Matched:
  EOR
    Ready:
    Foo:
      Bar:
    Matched:
  EOS

  _it 'does not match descendant preventing conditions with nodes with a differing label but the same value', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Ready:
      +Foo: 7.3

    ^:
      Ready:
      !...Bar: 7.3
      !Matched:
      +Matched:
  EOR
    Ready:
    Foo: 7.3
    Matched:
  EOS

  _it 'does not match descendant preventing conditions with nodes with a differing label but a matching child rule', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Ready:
      +Foo:
        Bar:

    ^:
      Ready:
      !...Baz:
        Bar:
      !Matched:
      +Matched:
  EOR
    Ready:
    Foo:
      Bar:
    Matched:
  EOS

  _it 'does not match descendant preventing conditions with descendant nodes with a differing label but the same value', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Ready:
      +Foo:
        Bar:
          Baz: 7.3

    ^:
      Ready:
      !...Qux: 7.3
      !Matched:
      +Matched:
  EOR
    Ready:
    Foo:
      Bar:
        Baz: 7.3
    Matched:
  EOS

  _it 'does not match descendant preventing conditions with descendant nodes with a differing label but a matching child rule', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Ready:
      +Foo:
        Bar:
          Baz:
            Qux:

    ^:
      Ready:
      !...Foobar:
        Qux:
      !Matched:
      +Matched:
  EOR
    Ready:
    Foo:
      Bar:
        Baz:
          Qux:
    Matched:
  EOS

  _it 'does not match preventing conditions with nodes with a differing label and value', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Ready:
      +Foo: 7.3

    ^:
      Ready:
      !Bar: 7.2
      !Matched:
      +Matched:
  EOR
    Ready:
    Foo: 7.3
    Matched:
  EOS

  _it 'does not match preventing conditions with nodes with a differing label and a non-matching child rule', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Ready:
      +Foo:
        Bar:

    ^:
      Ready:
      !Qux:
        Baz:
      !Matched:
      +Matched:
  EOR
    Ready:
    Foo:
      Bar:
    Matched:
  EOS

  _it 'does not match descendant preventing conditions with nodes with a differing label and value', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Ready:
      +Foo: 7.3

    ^:
      Ready:
      !...Bar: 7.2
      !Matched:
      +Matched:
  EOR
    Ready:
    Foo: 7.3
    Matched:
  EOS

  _it 'does not match descendant preventing conditions with nodes with a differing label and a non-matching child rule', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Ready:
      +Foo:
        Bar:

    ^:
      Ready:
      !...Qux:
        Baz:
      !Matched:
      +Matched:
  EOR
    Ready:
    Foo:
      Bar:
    Matched:
  EOS

  _it 'does not match descendant preventing conditions with descendant nodes with a differing label and value', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Ready:
      +Foo:
        Bar:
          Baz: 7.3

    ^:
      Ready:
      !...Qux: 7.2
      !Matched:
      +Matched:
  EOR
    Ready:
    Foo:
      Bar:
        Baz: 7.3
    Matched:
  EOS

  _it 'does not match descendant preventing conditions with descendant nodes with a differing label and a non-matching child rule', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Ready:
      +Foo:
        Bar:
          Baz:
            Qux:

    ^:
      Ready:
      !...Foobar:
        Foobaz:
      !Matched:
      +Matched:
  EOR
    Ready:
    Foo:
      Bar:
        Baz:
          Qux:
    Matched:
  EOS
end
