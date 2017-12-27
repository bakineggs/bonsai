RSpec.shared_examples 'multiplication action' do
  _it 'supplies the result of multiplying zero values', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
      Bar:* [Y]
    $:
      *:
        Factor:* [Y]
        Product: X
  EOR
    Foo: 1
  EOS

  _it 'supplies the result of multiplying one integer value', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      *:
        Factor: 7
        Product: X
  EOR
    Foo: 7
  EOS

  _it 'supplies the result of multiplying one decimal value', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      *:
        Factor: 7.4
        Product: X
  EOR
    Foo: 7.4
  EOS

  _it 'supplies the result of multiplying many integer values', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      *:
        Factor: 7
        Factor: 4
        Factor: 11
        Factor: 6
        Product: X
  EOR
    Foo: 1848
  EOS

  _it 'supplies the integer result of multiplying many decimal values', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      *:
        Factor: 7.4
        Factor: 4.3
        Factor: 12.5
        Factor: 8.0
        Product: X
  EOR
    Foo: 3182
  EOS

  _it 'supplies the decimal result of multiplying many decimal values', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      *:
        Factor: 7.4
        Factor: 4.307
        Factor: 11.05
        Factor: 6.09
        Product: X
  EOR
    Foo: 2144.7968451
  EOS

  _it 'supplies the integer result of multiplying integer and decimal values', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      *:
        Factor: 7.4
        Factor: 4.3
        Factor: 5
        Factor: 4
        Factor: 5
        Product: X
  EOR
    Foo: 3182
  EOS

  _it 'supplies the decimal result of multiplying integer and decimal values', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      *:
        Factor: 7
        Factor: 4.307
        Factor: 11
        Factor: 6.09
        Product: X
  EOR
    Foo: 2019.68151
  EOS

  _it 'supplies the result of multiplying multiple matched nodes', <<-EOR, <<-EOS
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
      *:
        Factor: F
        Factor:* [X]
        Product: Y
  EOR
    Foo: 3
    Bar: 4.7
    Baz: 1.4
    Qux: 19.74
  EOS

  _it 'supplies the integer factor needed to produce an integer result', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      *:
        Factor: 3
        Factor: X
        Product: 21
  EOR
    Foo: 7
  EOS

  _it 'supplies the decimal factor needed to produce an integer result', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      *:
        Factor: 6
        Factor: X
        Product: 21
  EOR
    Foo: 3.5
  EOS

  _it 'supplies the integer factor needed to produce a decimal result', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      *:
        Factor: 3.5
        Factor: X
        Product: 10.5
  EOR
    Foo: 3
  EOS

  _it 'supplies the decimal factor needed to produce a decimal result', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      *:
        Factor: 3
        Factor: X
        Product: 10.5
  EOR
    Foo: 3.5
  EOS

  _it 'does not supply more than one value', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
      +Bar: Y
    $:
      *:
        Factor: X
        Factor: 3
        Product: Y
  EOR
  EOS

  _it 'allows matching when values multiply to the correct product', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: 3
      +Bar: 4.63
      +Baz: 9.37
      +Qux: 130.1493

    ^:
      Foo: Foo
      Bar: Bar
      Baz: Baz
      Qux: Qux
      !Matched:
      +Matched:
    $:
      *:
        Factor: Foo
        Factor: Bar
        Factor: Baz
        Product: Qux
  EOR
    Foo: 3
    Bar: 4.63
    Baz: 9.37
    Qux: 130.1493
    Matched:
  EOS

  _it 'prevents matching when values multiply to an incorrect product', <<-EOR, <<-EOS
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
      *:
        Factor: Foo
        Factor: Bar
        Factor: Baz
        Product: Qux
  EOR
    Foo: 3
    Bar: 4.63
    Baz: 9.37
    Qux: 16
  EOS
end
