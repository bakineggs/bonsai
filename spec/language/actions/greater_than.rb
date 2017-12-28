RSpec.shared_examples 'greater than action' do
  _it 'supplies the result of comparing equal integer values', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      >:
        Left: 7
        Right: 7
        Result: X
  EOR
    Foo: 0
  EOS

  _it 'supplies the result of comparing a smaller integer value to a larger integer value', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      >:
        Left: 7
        Right: 8
        Result: X
  EOR
    Foo: 0
  EOS

  _it 'supplies the result of comparing a larger integer value to a smaller integer value', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      >:
        Left: 7
        Right: 6
        Result: X
  EOR
    Foo: 1
  EOS

  _it 'supplies the result of comparing equal decimal values', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      >:
        Left: 7.0
        Right: 7.0
        Result: X
  EOR
    Foo: 0
  EOS


  _it 'supplies the result of comparing a smaller decimal value to a larger decimal value', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      >:
        Left: 7.0
        Right: 8.0
        Result: X
  EOR
    Foo: 0
  EOS


  _it 'supplies the result of comparing a larger decimal value to a smaller decimal value', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      >:
        Left: 7.0
        Right: 6.0
        Result: X
  EOR
    Foo: 1
  EOS

  _it 'supplies the result of comparing equal integer and decimal values', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      >:
        Left: 7
        Right: 7.0
        Result: X
  EOR
    Foo: 0
  EOS

  _it 'supplies the result of comparing equal decimal and integer values', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      >:
        Left: 7.0
        Right: 7
        Result: X
  EOR
    Foo: 0
  EOS

  _it 'supplies the result of comparing a smaller integer value to a larger decimal value', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      >:
        Left: 7
        Right: 7.001
        Result: X
  EOR
    Foo: 0
  EOS


  _it 'supplies the result of comparing a larger integer value to a smaller decimal value', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      >:
        Left: 7
        Right: 6.999
        Result: X
  EOR
    Foo: 1
  EOS

  _it 'supplies the result of comparing a smaller decimal value to a larger integer value', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      >:
        Left: 6.999
        Right: 7
        Result: X
  EOR
    Foo: 0
  EOS

  _it 'supplies the result of comparing a larger decimal value to a smaller integer value', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      >:
        Left: 7.001
        Right: 7
        Result: X
  EOR
    Foo: 1
  EOS

  _it 'does not supply a left value that fits the inequality', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      >:
        Left: X
        Right: 7
        Result: 1
  EOR
  EOS

  _it 'does not supply a right value that fits the inequality', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      >:
        Left: 7
        Right: X
        Result: 1
  EOR
  EOS

  _it 'allows matching when the values fit the inequality', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: 7
      +Bar: 8
      +Baz: 0

    ^:
      Foo: Foo
      Bar: Bar
      Baz: Baz
      !Matched:
      +Matched:
    $:
      >:
        Left: Foo
        Right: Bar
        Result: Baz
  EOR
    Foo: 7
    Bar: 8
    Baz: 0
    Matched:
  EOS

  _it 'prevents matching when the values violate the inequality', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: 7
      +Bar: 6
      +Baz: 0

    ^:
      Foo: Foo
      Bar: Bar
      Baz: Baz
      !Matched:
      +Matched:
    $:
      >:
        Left: Foo
        Right: Bar
        Result: Baz
  EOR
    Foo: 7
    Bar: 6
    Baz: 0
  EOS
end
