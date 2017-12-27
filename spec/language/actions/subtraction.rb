RSpec.shared_examples 'subtraction action' do
  _it 'supplies the result of subtracting zero values', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
      Bar:* [Y]
    $:
      -:
        Minuend: 7
        Subtrahend:* [Y]
        Difference: X
  EOR
    Foo: 7
  EOS

  _it 'supplies the result of subtracting one integer value', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      -:
        Minuend: 7
        Subtrahend: 3
        Difference: X
  EOR
    Foo: 4
  EOS

  _it 'supplies the integer result of subtracting one decimal value', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      -:
        Minuend: 7.8
        Subtrahend: 3.8
        Difference: X
  EOR
    Foo: 4
  EOS

  _it 'supplies the decimal result of subtracting one decimal value', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      -:
        Minuend: 7.5
        Subtrahend: 3.8
        Difference: X
  EOR
    Foo: 3.7
  EOS

  _it 'supplies the result of subtracting many integer values', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      -:
        Minuend: 7
        Subtrahend: 3
        Subtrahend: 6
        Subtrahend: 4
        Difference: X
  EOR
    Foo: -6
  EOS

  _it 'supplies the integer result of subtracting many decimal values', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      -:
        Minuend: 7.6
        Subtrahend: 3.3
        Subtrahend: 6.8
        Subtrahend: 4.5
        Difference: X
  EOR
    Foo: -7
  EOS

  _it 'supplies the decimal result of subtracting many decimal values', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      -:
        Minuend: 7.6
        Subtrahend: 3.3
        Subtrahend: 6.8
        Subtrahend: 4.6
        Difference: X
  EOR
    Foo: -7.1
  EOS

  _it 'supplies the integer result of subtracting integer and decimal values', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      -:
        Minuend: 7
        Subtrahend: 3.6
        Subtrahend: 6
        Subtrahend: 4.4
        Difference: X
  EOR
    Foo: -7
  EOS

  _it 'supplies the decimal result of subtracting integer and decimal values', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      -:
        Minuend: 7
        Subtrahend: 3.6
        Subtrahend: 6
        Subtrahend: 4.5
        Difference: X
  EOR
    Foo: -7.1
  EOS

  _it 'supplies the result of subtracting multiple matched nodes', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: 3
      +Bar: 4.7
      +Baz: 1.4

    ^:=
      Foo: F
      *:* [X]
      !Qux:
      +Qux: Y
    $:
      -:
        Minuend: F
        Subtrahend:* [X]
        Difference: Y
  EOR
    Foo: 3
    Bar: 4.7
    Baz: 1.4
    Qux: -3.1
  EOS

  _it 'supplies the integer minuend needed to produce an integer result', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      -:
        Minuend: X
        Subtrahend: 7
        Difference: 5
  EOR
    Foo: 12
  EOS

  _it 'supplies the integer minuend needed to produce a decimal result', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      -:
        Minuend: X
        Subtrahend: 7.2
        Difference: 4.8
  EOR
    Foo: 12
  EOS

  _it 'supplies the decimal minuend needed to produce an integer result', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      -:
        Minuend: X
        Subtrahend: 7.2
        Difference: 5
  EOR
    Foo: 12.2
  EOS

  _it 'supplies the decimal minuend needed to produce a decimal result', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      -:
        Minuend: X
        Subtrahend: 7.3
        Difference: 5.4
  EOR
    Foo: 12.7
  EOS

  _it 'supplies the integer subtrahend needed to produce an integer result', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      -:
        Minuend: 12
        Subtrahend: X
        Difference: 5
  EOR
    Foo: 7
  EOS

  _it 'supplies the integer subtrahend needed to produce a decimal result', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      -:
        Minuend: 12.4
        Subtrahend: X
        Difference: 5.4
  EOR
    Foo: 7
  EOS

  _it 'supplies the decimal subtrahend needed to produce an integer result', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      -:
        Minuend: 12.6
        Subtrahend: X
        Difference: 5
  EOR
    Foo: 7.6
  EOS

  _it 'supplies the decimal subtrahend needed to produce a decimal result', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      -:
        Minuend: 12.4
        Subtrahend: X
        Difference: 5.2
  EOR
    Foo: 7.2
  EOS

  _it 'does not supply more than one value', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
      +Bar: Y
    $:
      -:
        Minuend: X
        Subtrahend: 7
        Difference: Y
  EOR
  EOS

  _it 'allows matching when the values subtract to the correct difference', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: 12
      +Bar: 4.7
      +Baz: 9.3
      +Qux: -2

    ^:
      Foo: Foo
      Bar: Bar
      Baz: Baz
      Qux: Qux
      !Matched:
      +Matched:
    $:
      -:
        Minuend: Foo
        Subtrahend: Bar
        Subtrahend: Baz
        Difference: Qux
  EOR
    Foo: 12
    Bar: 4.7
    Baz: 9.3
    Qux: -2
    Matched:
  EOS

  _it 'prevents matching when the values subtract to the correct difference', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: 12
      +Bar: 4.7
      +Baz: 9.3
      +Qux: -1

    ^:
      Foo: Foo
      Bar: Bar
      Baz: Baz
      Qux: Qux
      !Matched:
      +Matched:
    $:
      -:
        Minuend: Foo
        Subtrahend: Bar
        Subtrahend: Baz
        Difference: Qux
  EOR
    Foo: 12
    Bar: 4.7
    Baz: 9.3
    Qux: -1
  EOS
end
