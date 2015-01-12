RSpec.shared_examples 'visiting nodes' do
  _it 'applies rules to the root', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo:
  EOR
    Foo:
  EOS

  _it 'applies rules to newly created nodes', <<-EOR, <<-EOS
    ^:
      !Foo:
      +Foo:
        Bar:

    Bar:
      !Baz:
      +Baz:
  EOR
    Foo:
      Bar:
        Baz:
  EOS

  _it 'applies rules to ancestors of modified nodes', <<-EOR, <<-EOS
    ^:
      Foo:
        Bar:
      !Baz:
      +Baz:

    ^:
      !Foo:
      +Foo:

    Foo:
      !Bar:
      +Bar:
  EOR
    Foo:
      Bar:
    Baz:
  EOS
end
