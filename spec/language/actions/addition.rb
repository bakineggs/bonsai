RSpec.shared_examples 'addition action' do
  _it 'supplies the result of adding zero values', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
      Bar:* [Y]
    $:
      +:
        Addend:* [Y]
        Sum: X
  EOR
    Foo: 0
  EOS

  _it 'supplies the result of adding one integer value', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      +:
        Addend: 7
        Sum: X
  EOR
    Foo: 7
  EOS

  _it 'supplies the result of adding one decimal value', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      +:
        Addend: 7.4
        Sum: X
  EOR
    Foo: 7.4
  EOS

  _it 'supplies the result of adding many integer values', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      +:
        Addend: 7
        Addend: 4
        Addend: 11
        Addend: 6
        Sum: X
  EOR
    Foo: 28
  EOS

  _it 'supplies the decimal result of adding many decimal values', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      +:
        Addend: 7.4
        Addend: 4.307
        Addend: 11.05
        Addend: 6.09
        Sum: X
  EOR
    Foo: 28.847
  EOS

  _it 'supplies the integer result of adding many decimal values', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      +:
        Addend: 7.4
        Addend: 4.307
        Addend: 11.05
        Addend: 6.243
        Sum: X
  EOR
    Foo: 29
  EOS

  _it 'supplies the decimal result of adding integer and decimal values', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      +:
        Addend: 7
        Addend: 4.307
        Addend: 47
        Addend: 6.09
        Sum: X
  EOR
    Foo: 64.397
  EOS

  _it 'supplies the integer result of adding integer and decimal values', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      +:
        Addend: 7
        Addend: 4.91
        Addend: 47
        Addend: 6.09
        Sum: X
  EOR
    Foo: 65
  EOS

  _it 'supplies the result of adding multiple matched nodes', <<-EOR, <<-EOS
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
      +:
        Addend: F
        Addend:* [X]
        Sum: Y
  EOR
    Foo: 3
    Bar: 4.7
    Baz: 1.4
    Qux: 9.1
  EOS

  _it 'supplies the integer addend needed to produce an integer result', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      +:
        Addend: 4
        Addend: X
        Sum: 7
  EOR
    Foo: 3
  EOS

  _it 'supplies the integer addend needed to produce a decimal result', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      +:
        Addend: 4.3
        Addend: X
        Sum: 7.3
  EOR
    Foo: 3
  EOS

  _it 'supplies the decimal addend needed to produce an integer result', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      +:
        Addend: 4.3
        Addend: X
        Sum: 7
  EOR
    Foo: 2.7
  EOS

  _it 'supplies the decimal addend needed to produce a decimal result', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      +:
        Addend: 4.3
        Addend: X
        Sum: 7.1
  EOR
    Foo: 2.8
  EOS

  _it 'does not supply more than one value', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
      +Bar: Y
    $:
      +:
        Addend: X
        Addend: 3
        Sum: Y
  EOR
  EOS

  _it 'allows matching when values add up to the correct sum', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: 3
      +Bar: 4.63
      +Baz: 9.37
      +Qux: 17

    ^:
      Foo: Foo
      Bar: Bar
      Baz: Baz
      Qux: Qux
      !Matched:
      +Matched:
    $:
      +:
        Addend: Foo
        Addend: Bar
        Addend: Baz
        Sum: Qux
  EOR
    Foo: 3
    Bar: 4.63
    Baz: 9.37
    Qux: 17
    Matched:
  EOS

  _it 'prevents matching when values add up to an incorrect sum', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: 3
      +Bar: 4.63
      +Baz: 9.37
      +Qux: 16

    ^:
      Foo: Foo
      Bar: Bar
      Baz: Baz
      Qux: Qux
      !Matched:
      +Matched:
    $:
      +:
        Addend: Foo
        Addend: Bar
        Addend: Baz
        Sum: Qux
  EOR
    Foo: 3
    Bar: 4.63
    Baz: 9.37
    Qux: 16
  EOS
end
