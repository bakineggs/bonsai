shared_examples_for 'an okk implementation' do
  def parse_state definition
    nodes = definition.split "\n"
    state = []

    return state if nodes.empty?
    depth = nodes.first.match(/^ */)[0].length

    parent = nodes.shift
    children = []
    nodes.each do |node|
      if node.match /^ {#{depth}}[^ ]/
        state += [{:label => parent.sub(/^ {#{depth}}/, ''), :children => parse_state(children.join "\n")}]
        parent = node
        children = []
      else
        children += [node]
      end
    end
    state + [{:label => parent.sub(/^ {#{depth}}/, ''), :children => parse_state(children.join "\n")}]
  end

  describe 'halting' do
    it 'errors out when no rules match' do
      result = run_program :rules => "Foo:", :start_state => "Bar:"
      result[:exit_status].should == 1
      result[:stdout].should == ""
      result[:stderr].should == "No rules to apply!\nBar:\n"
      result[:end_state].should == parse_state('Bar:')
    end

    it 'errors out when no rules make a change' do
      result = run_program :rules => "Foo:", :start_state => "Foo:"
      result[:exit_status].should == 1
      result[:stdout].should == ""
      result[:stderr].should == "No rules to apply!\nFoo:\n"
      result[:end_state].should == parse_state('Foo:')
    end
  end

  describe 'executing code' do
    it 'executes code of a matched rule' do
      result = run_program :rules => "Foo:\n< exit(0);", :start_state => "Foo:"
      result[:exit_status].should == 0
      result[:stdout].should == ""
      result[:stderr].should == ""
      result[:end_state].should be_nil
    end

    it 'executes lines of code in order' do
      result = run_program :rules => "Foo:\n< printf(\"bar\");\n< exit(0);", :start_state => "Foo:"
      result[:exit_status].should == 0
      result[:stdout].should == "bar"
      result[:stderr].should == ""
      result[:end_state].should be_nil
    end

    it 'does not execute code of an unmatched rule' do
      result = run_program :rules => "Foo:\n< exit(0);", :start_state => "Bar:"
      result[:exit_status].should == 1
      result[:stdout].should == ""
      result[:stderr].should == "No rules to apply!\nBar:\n"
      result[:end_state].should == parse_state('Bar:')
    end

    it 'causes a gcc error with invalid code' do
      result = run_program :rules => "Foo:\n< not_valid_code;", :start_state => "Bar:"
      result[:gcc_error].should be_true
      result[:exit_status].should be_nil
      result[:stdout].should be_nil
      result[:stderr].should be_nil
      result[:end_state].should be_nil
    end
  end

  describe 'header' do
    it 'makes included code callable' do
      header = <<-EOS
        %{
          void e() { exit(0); }
        %}
      EOS
      result = run_program :rules => "Foo:\n< e();", :start_state => "Foo:", :header => header
      result[:exit_status].should == 0
      result[:stdout].should == ""
      result[:stderr].should == ""
      result[:end_state].should be_nil
    end

    it 'causes a gcc error with invalid code' do
      header = <<-EOS
        %{
          void e() { not_valid_code; }
        %}
      EOS
      result = run_program :rules => "Foo:\n< exit(0);", :start_state => "Foo:", :header => header
      result[:gcc_error].should be_true
      result[:exit_status].should be_nil
      result[:stdout].should be_nil
      result[:stderr].should be_nil
      result[:end_state].should be_nil
    end
  end

  describe 'root label' do
    it 'applies the rule when conditions match at the root level' do
      rules = <<-EOS
        ^:
          Foo:
        < exit(0);
      EOS
      start_state = <<-EOS
        Bar:
        Foo:
        Baz:
      EOS
      result = run_program :rules => rules, :start_state => start_state
      result[:exit_status].should == 0
    end

    it 'does not apply the rule when conditions match below the root level' do
      rules = <<-EOS
        ^:
          Foo:
        < exit(0);
      EOS
      start_state = <<-EOS
        Bar:
          Foo:
        Baz:
      EOS
      result = run_program :rules => rules, :start_state => start_state
      result[:exit_status].should == 1
      result[:end_state].should == parse_state(start_state)
    end
  end

  describe 'creating nodes' do
    describe 'at the root level' do
      it 'creates the node' do
        rules = <<-EOS
          Foo:
          < exit(0);

          +Foo:
        EOS
        result = run_program :rules => rules, :start_state => ''
        result[:exit_status].should == 0
      end
    end

    describe 'in a child condition' do
      describe 'with a matching parent' do
        it 'creates the node' do
          rules = <<-EOS
            Foo:
            < exit(0);

            Bar:
              +Foo:
          EOS
          result = run_program :rules => rules, :start_state => 'Bar:'
          result[:exit_status].should == 0
        end
      end

      describe 'without a matching parent' do
        it 'does not create the node' do
          rules = <<-EOS
            Foo:
            < exit(0);

            Bar:
              +Foo:
          EOS
          result = run_program :rules => rules, :start_state => 'Baz:'
          result[:exit_status].should == 1
          result[:end_state].should == parse_state('Baz:')
        end
      end
    end

    describe 'with children' do
      it 'creates the children' do
        rules = <<-EOS
          Foo:
          < exit(0);

          +Bar:
            Foo:
        EOS
        result = run_program :rules => rules, :start_state => ''
        result[:exit_status].should == 0
      end
    end
  end

  describe 'removing nodes' do
    describe 'at the root level' do
      it 'removes the node' do
        result = run_program :rules => '-Foo:', :start_state => 'Foo:'
        result[:exit_status].should == 1
        result[:end_state].should == parse_state('')
      end
    end

    describe 'in a child condition' do
      it 'removes the node' do
        rules = <<-EOS
          Foo:
            -Bar:
        EOS
        start_state = <<-EOS
          Foo:
            Bar:
        EOS
        result = run_program :rules => rules, :start_state => start_state
        result[:exit_status].should == 1
        result[:end_state].should == parse_state('Foo:')
      end
    end

    describe 'with children' do
      describe 'that match' do
        it 'removes the node' do
          rules = <<-EOS
            -Foo:
              Bar:
          EOS
          start_state = <<-EOS
            Foo:
              Bar:
          EOS
          result = run_program :rules => rules, :start_state => start_state
          result[:exit_status].should == 1
          result[:end_state].should == parse_state('')
        end
      end

      describe 'that do not match' do
        it 'does not remove the node' do
          rules = <<-EOS
            -Foo:
              Bar:
          EOS
          start_state = <<-EOS
            Foo:
              Baz:
          EOS
          result = run_program :rules => rules, :start_state => start_state
          result[:exit_status].should == 1
          result[:end_state].should == parse_state(start_state)
        end
      end
    end
  end

  describe 'preventing a match' do
    it 'applies the rule if a match-preventing condition does not match' do
      rules = <<-EOS
        !Foo:
        -Bar:
      EOS
      start_state = <<-EOS
        Bar:
        Baz:
      EOS
      result = run_program :rules => rules, :start_state => start_state
      result[:end_state].should == parse_state("Baz:")
    end

    it 'does not apply the rule if a match-preventing condition matches' do
      rules = <<-EOS
        !Foo:
        -Bar:
      EOS
      start_state = <<-EOS
        Bar:
        Foo:
      EOS
      result = run_program :rules => rules, :start_state => start_state
      result[:end_state].should == parse_state(start_state)
    end
  end

  describe 'unordered child conditions' do
    let(:rules) do
      <<-EOS
        Foo:
          Bar:
          Baz:
        < exit(0);
      EOS
    end

    describe 'matching unordered child nodes' do
      describe 'that match in order' do
        it 'applies the rule' do
          start_state = <<-EOS
            Foo:
              Bar:
              Baz:
          EOS
          result = run_program :rules => rules, :start_state => start_state
          result[:exit_status].should == 0
        end
      end

      describe 'that match out of order' do
        it 'applies the rule' do
          start_state = <<-EOS
            Foo:
              Baz:
              Bar:
          EOS
          result = run_program :rules => rules, :start_state => start_state
          result[:exit_status].should == 0
        end
      end
    end

    describe 'matching ordered child nodes' do
      describe 'that match in order' do
        it 'applies the rule' do
          start_state = <<-EOS
            Foo::
              Bar:
              Baz:
          EOS
          result = run_program :rules => rules, :start_state => start_state
          result[:exit_status].should == 0
        end
      end

      describe 'that match out of order' do
        it 'applies the rule' do
          start_state = <<-EOS
            Foo::
              Baz:
              Bar:
          EOS
          result = run_program :rules => rules, :start_state => start_state
          result[:exit_status].should == 0
        end
      end
    end
  end

  describe 'ordered child conditions' do
    let(:rules) do
      <<-EOS
        Foo::
          Bar:
          Baz:
        < exit(0);
      EOS
    end

    describe 'matching unordered child nodes' do
      describe 'that match in order' do
        it 'does not apply the rule' do
          start_state = <<-EOS
            Foo:
              Bar:
              Baz:
          EOS
          result = run_program :rules => rules, :start_state => start_state
          result[:exit_status].should == 1
          result[:end_state].should == parse_state(start_state)
        end
      end

      describe 'that match out of order' do
        it 'does not apply the rule' do
          start_state = <<-EOS
            Foo:
              Baz:
              Bar:
          EOS
          result = run_program :rules => rules, :start_state => start_state
          result[:exit_status].should == 1
          result[:end_state].should == parse_state(start_state)
        end
      end
    end

    describe 'matching ordered child nodes' do
      describe 'that match in order' do
        describe 'from the beginning' do
          it 'applies the rule' do
            start_state = <<-EOS
              Foo::
                Bar:
                Baz:
            EOS
            result = run_program :rules => rules, :start_state => start_state
            result[:exit_status].should == 0
          end
        end

        describe 'from the middle' do
          it 'does not apply the rule' do
            start_state = <<-EOS
              Foo::
                Qux:
                Bar:
                Baz:
            EOS
            result = run_program :rules => rules, :start_state => start_state
            result[:exit_status].should == 1
            result[:end_state].should == parse_state(start_state)
          end
        end
      end

      describe 'that match out of order' do
        it 'does not apply the rule' do
          start_state = <<-EOS
            Foo::
              Baz:
              Bar:
          EOS
          result = run_program :rules => rules, :start_state => start_state
          result[:exit_status].should == 1
          result[:end_state].should == parse_state(start_state)
        end
      end
    end
  end

  describe 'matching multiple nodes' do
    let(:rules) do
      <<-EOS
        -Foo:
        -Bar:*
      EOS
    end

    describe 'with no nodes that match' do
      it 'applies the rule' do
        start_state = <<-EOS
          Foo:
        EOS
        result = run_program :rules => rules, :start_state => start_state
        result[:exit_status].should == 1
        result[:end_state].should == parse_state('')
      end
    end

    describe 'with one node that matches' do
      it 'applies the rule' do
        start_state = <<-EOS
          Foo:
          Bar:
        EOS
        result = run_program :rules => rules, :start_state => start_state
        result[:exit_status].should == 1
        result[:end_state].should == parse_state('')
      end
    end

    describe 'with multiple nodes that match' do
      it 'applies the rule' do
        start_state = <<-EOS
          Foo:
          Bar:
          Bar:
        EOS
        result = run_program :rules => rules, :start_state => start_state
        result[:exit_status].should == 1
        result[:end_state].should == parse_state('')
      end
    end
  end

  describe 'not matching all nodes with a condition' do
    let(:rules) do
      <<-EOS
        Foo:
          Bar:
          Baz:
        < exit(0);
      EOS
    end

    describe 'with all child nodes matching' do
      it 'applies the rule' do
        start_state = <<-EOS
          Foo:
            Bar:
            Baz:
        EOS
        result = run_program :rules => rules, :start_state => start_state
        result[:exit_status].should == 0
      end
    end

    describe 'with some child nodes not matching' do
      it 'applies the rule' do
        start_state = <<-EOS
          Foo:
            Bar:
            Baz:
            Qux:
        EOS
        result = run_program :rules => rules, :start_state => start_state
        result[:exit_status].should == 0
      end
    end
  end

  describe 'matching all nodes with a condition' do
    let(:rules) do
      <<-EOS
        Foo:=
          Bar:
          Baz:
        < exit(0);
      EOS
    end

    describe 'with all child nodes matching' do
      it 'applies the rule' do
        start_state = <<-EOS
          Foo:
            Bar:
            Baz:
        EOS
        result = run_program :rules => rules, :start_state => start_state
        result[:exit_status].should == 0
      end
    end

    describe 'with some child nodes not matching' do
      it 'does not apply the rule' do
        start_state = <<-EOS
          Foo:
            Bar:
            Baz:
            Qux:
        EOS
        result = run_program :rules => rules, :start_state => start_state
        result[:exit_status].should == 1
        result[:end_state].should == parse_state(start_state)
      end
    end
  end

  describe 'node values' do
    # TODO
  end

  describe 'variables' do
    describe 'that duplicate' do
      let(:rules) do
        <<-EOS
          Foo: X
          !Bar:
          +Bar: X
        EOS
      end

      describe 'integer values' do
        it 'allows a node to be duplicated' do
          result = run_program :rules => rules, :start_state => 'Foo: 5'
          result[:exit_status].should == 1
          result[:end_state].should == parse_state("Foo: 5\nBar: 5")
        end

        it 'does not link the original and duplicated value' do
          rules = <<-EOS
            Foo: X
            !Bar:
            +Bar: X

            Bar: X
            !Baz:
            +Baz:
            < $X->integer_value++;
          EOS
          result = run_program :rules => rules, :start_state => 'Foo: 5'
          result[:exit_status].should == 1
          result[:end_state].should == parse_state("Foo: 5\nBar: 6")
        end
      end

      describe 'decimal values' do
        it 'allows a node to be duplicated' do
          result = run_program :rules => rules, :start_state => 'Foo: 5.7'
          result[:exit_status].should == 1
          result[:end_state].should == parse_state("Foo: 5.7\nBar: 5.7")
        end

        it 'does not link the original and duplicated value' do
          rules = <<-EOS
            Foo: X
            !Bar:
            +Bar: X

            Bar: X
            !Baz:
            +Baz:
            < $X->decimal_value++;
          EOS
          result = run_program :rules => rules, :start_state => 'Foo: 5.7'
          result[:exit_status].should == 1
          result[:end_state].should == parse_state("Foo: 5.7\nBar: 6.7")
        end
      end

      describe 'child nodes' do
        let(:start_state) do
          <<-EOS
            Foo:
              Bar:
                Baz:
              Qux: 5.7
          EOS
        end

        it 'allows a node to be duplicated' do
          result = run_program :rules => rules, :start_state => start_state
          result[:exit_status].should == 1
          result[:end_state].should == parse_state("#{start_state}\n#{start_state.sub('Foo','Bar')}")
        end

        it 'does not link the original and duplicated children' do
          rules = <<-EOS
            Foo: X
            !Bar:
            +Bar: X

            Bar:
              Bar:
                -Baz:

            Foo:
              Qux: X
            !Baz:
            +Baz:
            < $X->decimal_value++;
          EOS
          end_state = <<-EOS
            Foo:
              Bar:
                Baz:
              Qux: 6.7
            Bar:
              Bar:
              Qux: 5.7
          EOS
          result = run_program :rules => rules, :start_state => start_state
          result[:exit_status].should == 1
          result[:end_state].should == parse_state(end_state)
        end
      end
    end

    describe 'matched multiple times' do
      let(:rules) do
        <<-EOS
          Foo: X
          -Bar: X
        EOS
      end

      describe 'matching a value and a node\'s children' do
        it 'prevents the rule from matching' do
          start_state = <<-EOS
            Foo: 5
            Bar:
              Baz:
          EOS
          result = run_program :rules => rules, :start_state => start_state
          result[:exit_status].should == 1
          result[:end_state].should == parse_state(start_state)
        end
      end

      describe 'matching values' do
        describe 'of different types' do
          it 'prevents the rule from matching' do
            start_state = <<-EOS
              Foo: 5
              Bar: 5.0
            EOS
            result = run_program :rules => rules, :start_state => start_state
            result[:exit_status].should == 1
            result[:end_state].should == parse_state(start_state)
          end
        end

        describe 'that are equal' do
          it 'allows the rule to match' do
            start_state = <<-EOS
              Foo: 5
              Bar: 5
            EOS
            result = run_program :rules => rules, :start_state => start_state
            result[:exit_status].should == 1
            result[:end_state].should == parse_state('Foo: 5')
          end
        end

        describe 'that are unequal' do
          it 'prevents the rule from matching' do
            start_state = <<-EOS
              Foo: 5
              Bar: 6
            EOS
            result = run_program :rules => rules, :start_state => start_state
            result[:exit_status].should == 1
            result[:end_state].should == parse_state(start_state)
          end
        end
      end

      describe 'matching the nodes\' children' do
        describe 'that are equal' do
          it 'allows the rule to match' do
            start_state = <<-EOS
              Foo:
                Baz:
              Bar:
                Baz:
            EOS
            result = run_program :rules => rules, :start_state => start_state
            result[:exit_status].should == 1
            result[:end_state].should == parse_state("Foo:\n  Baz:")
          end
        end

        describe 'with values' do
          describe 'that are equal' do
            it 'allows the rule to match' do
              start_state = <<-EOS
                Foo:
                  Baz: 5
                Bar:
                  Baz: 5
              EOS
              result = run_program :rules => rules, :start_state => start_state
              result[:exit_status].should == 1
              result[:end_state].should == parse_state("Foo:\n  Baz: 5")
            end
          end

          describe 'that are unequal' do
            it 'prevents the rule from matching' do
              start_state = <<-EOS
                Foo:
                  Baz: 5
                Bar:
                  Baz: 6
              EOS
              result = run_program :rules => rules, :start_state => start_state
              result[:exit_status].should == 1
              result[:end_state].should == parse_state(start_state)
            end
          end

          describe 'that are different types' do
            it 'prevents the rule from matching' do
              start_state = <<-EOS
                Foo:
                  Baz: 5
                Bar:
                  Baz: 5.0
              EOS
              result = run_program :rules => rules, :start_state => start_state
              result[:exit_status].should == 1
              result[:end_state].should == parse_state(start_state)
            end
          end
        end

        describe 'and grandchildren' do
          describe 'that are equal' do
            it 'allows the rule to match' do
              start_state = <<-EOS
                Foo:
                  Baz:
                    Qux:
                Bar:
                  Baz:
                    Qux:
              EOS
              result = run_program :rules => rules, :start_state => start_state
              result[:exit_status].should == 1
              result[:end_state].should == parse_state("Foo:\n  Baz:\n    Qux:")
            end
          end

          describe 'that are unequal' do
            it 'prevents the rule from matching' do
              start_state = <<-EOS
                Foo:
                  Baz:
                    Qux:
                Bar:
                  Baz:
                    FooQux:
              EOS
              result = run_program :rules => rules, :start_state => start_state
              result[:exit_status].should == 1
              result[:end_state].should == parse_state(start_state)
            end
          end

          describe 'with values' do
            describe 'that are equal' do
              it 'allows the rule to match' do
                start_state = <<-EOS
                  Foo:
                    Baz:
                      Qux: 5
                  Bar:
                    Baz:
                      Qux: 5
                EOS
                result = run_program :rules => rules, :start_state => start_state
                result[:exit_status].should == 1
                result[:end_state].should == parse_state("Foo:\n  Baz:\n    Qux: 5")
              end
            end

            describe 'that are unequal' do
              it 'prevents the rule from matching' do
                start_state = <<-EOS
                  Foo:
                    Baz:
                      Qux: 5
                  Bar:
                    Baz:
                      Qux: 6
                EOS
                result = run_program :rules => rules, :start_state => start_state
                result[:exit_status].should == 1
                result[:end_state].should == parse_state(start_state)
              end
            end

            describe 'that are different types' do
              it 'prevents the rule from matching' do
                start_state = <<-EOS
                  Foo:
                    Baz:
                      Qux: 5
                  Bar:
                    Baz:
                      Qux: 5.0
                EOS
                result = run_program :rules => rules, :start_state => start_state
                result[:exit_status].should == 1
                result[:end_state].should == parse_state(start_state)
              end
            end
          end
        end
      end
    end

    describe 'used in a code segment' do
      it 'allows the matched node to be accessed' do
        rules = <<-EOS
          Foo: X
          !Bar:
          +Bar:
          < $X->integer_value++;
        EOS
        result = run_program :rules => rules, :start_state => "Foo: 5"
        result[:exit_status].should == 1
        result[:end_state].should == parse_state("Foo: 6\nBar:")
      end
    end
  end

  describe 'conditions at the top level of a rule' do
    let(:rules) do
      <<-EOS
        -Foo:
        -Bar:
      EOS
    end

    describe 'in unordered contexts' do
      it 'matches them' do
        start_state = <<-EOS
          Baz:
            Bar:
            Foo:
        EOS
        result = run_program :rules => rules, :start_state => start_state
        result[:end_state].should == parse_state('Baz:')
      end
    end

    describe 'in ordered contexts' do
      describe 'matching from the beginning' do
        it 'matches them' do
          start_state = <<-EOS
            Baz::
              Foo:
              Bar:
          EOS
          result = run_program :rules => rules, :start_state => start_state
          result[:end_state].should == parse_state('Baz:')
        end
      end

      describe 'matching from the middle' do
        it 'matches them' do
          start_state = <<-EOS
            Baz::
              Qux:
              Foo:
              Bar:
          EOS
          result = run_program :rules => rules, :start_state => start_state
          result[:end_state].should == parse_state('Baz:')
        end
      end

      describe 'matching out of order' do
        it 'does not match them' do
          start_state = <<-EOS
            Baz::
              Bar:
              Foo:
          EOS
          result = run_program :rules => rules, :start_state => start_state
          result[:end_state].should == parse_state(start_state)
        end
      end
    end
  end
end
