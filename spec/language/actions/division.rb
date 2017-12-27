RSpec.shared_examples 'division action' do
  _it 'supplies the integer result of dividing integer values', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      /:
        Dividend: 21
        Divisor: 3
        Quotient: X
  EOR
    Foo: 7
  EOS

  _it 'supplies the decimal result of dividing integer values', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      /:
        Dividend: 26
        Divisor: 4
        Quotient: X
  EOR
    Foo: 6.5
  EOS

  _it 'supplies the integer result of dividing decimal values', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      /:
        Dividend: 25.2
        Divisor: 6.3
        Quotient: X
  EOR
    Foo: 4
  EOS

  _it 'supplies the decimal result of dividing decimal values', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      /:
        Dividend: 28.35
        Divisor: 6.3
        Quotient: X
  EOR
    Foo: 4.5
  EOS

  _it 'supplies the integer dividend needed to produce an integer result', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      /:
        Dividend: X
        Divisor: 7
        Quotient: 3
  EOR
    Foo: 21
  EOS

  _it 'supplies the integer dividend needed to produce a decimal result', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      /:
        Dividend: X
        Divisor: 4
        Quotient: 6.5
  EOR
    Foo: 26
  EOS

  _it 'supplies the decimal dividend needed to produce an integer result', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      /:
        Dividend: X
        Divisor: 6.3
        Quotient: 4
  EOR
    Foo: 25.2
  EOS

  _it 'supplies the decimal dividend needed to produce a decimal result', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      /:
        Dividend: X
        Divisor: 4
        Quotient: 6.3
  EOR
    Foo: 25.2
  EOS

  _it 'supplies the integer divisor needed to produce an integer result', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      /:
        Dividend: 21
        Divisor: X
        Quotient: 3
  EOR
    Foo: 7
  EOS


  _it 'supplies the integer divisor needed to produce a decimal result', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      /:
        Dividend: 25.2
        Divisor: X
        Quotient: 6.3
  EOR
    Foo: 4
  EOS

  _it 'supplies the decimal divisor needed to produce an integer result', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      /:
        Dividend: 26
        Divisor: X
        Quotient: 4
  EOR
    Foo: 6.5
  EOS

  _it 'supplies the decimal divisor needed to produce a decimal result', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
    $:
      /:
        Dividend: 29.25
        Divisor: X
        Quotient: 6.5
  EOR
    Foo: 4.5
  EOS

  _it 'does not supply more than one value', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: X
      +Bar: Y
    $:
      /:
        Dividend: 29.25
        Divisor: X
        Quotient: Y
  EOR
  EOS

  _it 'allows matching when values divide to the correct quotient', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: 26
      +Bar: 6.5
      +Baz: 4

    ^:
      Foo: Foo
      Bar: Bar
      Baz: Baz
      !Matched:
      +Matched:
    $:
      /:
        Dividend: Foo
        Divisor: Bar
        Quotient: Baz
  EOR
    Foo: 26
    Bar: 6.5
    Baz: 4
    Matched:
  EOS

  _it 'prevents matching when values divide to an incorrect quotient', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo: 25
      +Bar: 6.5
      +Baz: 4

    ^:
      Foo: Foo
      Bar: Bar
      Baz: Baz
      !Matched:
      +Matched:
    $:
      /:
        Dividend: Foo
        Divisor: Bar
        Quotient: Baz
  EOR
    Foo: 25
    Bar: 6.5
    Baz: 4
  EOS
end
