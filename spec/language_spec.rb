shared_examples_for 'an okk implementation' do
  let(:header) { "" }
  subject { run_program :rules => rules, :start_state => start_state, :header => header }

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
    let(:rules) { "Foo:" }

    describe 'when no rules match' do
      let(:start_state) { "Bar:" }
      it 'errors out' do
        subject[:exit_status].should == 1
        subject[:stdout].should == ""
        subject[:stderr].should == "No rules to apply!\n#{start_state}\n"
        subject[:end_state].should == parse_state(start_state)
      end
    end

    describe 'when no rules make a change' do
      let(:start_state) { "Foo:" }
      it 'errors out' do
        subject[:exit_status].should == 1
        subject[:stdout].should == ""
        subject[:stderr].should == "No rules to apply!\n#{start_state}\n"
        subject[:end_state].should == parse_state(start_state)
      end
    end
  end

  describe 'executing code' do
    let(:start_state) { "Foo:" }

    describe 'of a matched rule' do
      let(:rules) { "Foo:\n< exit(0);" }
      it 'executes the code' do
        subject[:exit_status].should == 0
        subject[:stdout].should == ""
        subject[:stderr].should == ""
        subject[:end_state].should be_nil
      end

      describe 'with multiple lines of code' do
        let(:rules) { "Foo:\n< printf(\"bar\");\n< exit(0);" }
        it 'executes the code' do
          subject[:exit_status].should == 0
          subject[:stdout].should == "bar"
          subject[:stderr].should == ""
          subject[:end_state].should be_nil
        end
      end
    end

    describe 'of an unmatched rule' do
      let(:rules) { "Bar:\n< exit(0);" }
      it 'does not execute the code' do
        subject[:exit_status].should == 1
        subject[:stdout].should == ""
        subject[:stderr].should == "No rules to apply!\n#{start_state}\n"
        subject[:end_state].should == parse_state(start_state)
      end
    end

    describe 'that is invalid' do
      let(:rules) { "Bar:\n< not_valid_code;" }
      it 'causes a compile error' do
        subject[:compile_error].should be_true
        subject[:exit_status].should be_nil
        subject[:stdout].should be_nil
        subject[:stderr].should be_nil
        subject[:end_state].should be_nil
      end
    end
  end

  describe 'header' do
    let(:header) { <<-EOS }
      %{
        void f() {
          #{code}
        }
      %}
    EOS
    let(:rules) { "Foo:\n< f();" }
    let(:start_state) { "Foo:" }

    describe 'with valid code' do
      let(:code) { "exit(0);" }
      it 'exectutes the code' do
        subject[:exit_status].should == 0
        subject[:stdout].should == ""
        subject[:stderr].should == ""
        subject[:end_state].should be_nil
      end
    end

    describe 'with invalid code' do
      let(:code) { "not_valid_code;" }
      it 'causes a compile error' do
        subject[:compile_error].should be_true
        subject[:exit_status].should be_nil
        subject[:stdout].should be_nil
        subject[:stderr].should be_nil
        subject[:end_state].should be_nil
      end
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
    describe 'referenced in a matching condition' do
      let(:rules) { <<-EOS }
        Foo: X
        !Bar:
        +Bar:
      EOS

      describe 'used in a code segment' do
        let(:rules) { <<-EOS }
          Foo: X
          !Bar:
          +Bar:
          < #{target}->value_type = integer;
          < #{target}->integer_value = 5;
        EOS
        let(:target) { '$X' }

        describe 'matching a leaf node' do
          let(:start_state) { "Foo:" }

          it 'applies the rule' do
            subject[:exit_status].should == 1
            subject[:end_state].should == parse_state("Foo: 5\nBar:")
          end
        end

        describe 'matching a node with children' do
          let(:start_state) { "Foo:\n  Baz:" }
          let(:target) { '$X->children' }

          it 'applies the rule' do
            subject[:exit_status].should == 1
            subject[:end_state].should == parse_state("Foo:\n  Baz: 5\nBar:")
          end
        end

        describe 'matching a node with a value' do
          let(:start_state) { "Foo: 4" }

          it 'applies the rule' do
            subject[:exit_status].should == 1
            subject[:end_state].should == parse_state("Foo: 5\nBar:")
          end
        end
      end

      describe 'matching a leaf node' do
        let(:start_state) { "Foo:" }

        it 'applies the rule' do
          subject[:exit_status].should == 1
          subject[:end_state].should == parse_state("#{start_state}\nBar:")
        end
      end

      describe 'matching a node with children' do
        let(:start_state) { "Foo:\n  Baz:" }

        it 'applies the rule' do
          subject[:exit_status].should == 1
          subject[:end_state].should == parse_state("#{start_state}\nBar:")
        end
      end

      describe 'matching a node with a value' do
        let(:start_state) { "Foo: 4" }

        it 'applies the rule' do
          subject[:exit_status].should == 1
          subject[:end_state].should == parse_state("#{start_state}\nBar:")
        end
      end

      describe 'and another matching condition' do
        let(:rules) { <<-EOS }
          Foo: X
          Bar: X
          !Baz:
          +Baz:
        EOS

        describe 'used in a code segment' do
          let(:rules) { <<-EOS }
            Foo: X
            Bar: X
            !Baz:
            +Baz:
            < $X->value_type = none;
          EOS
          let(:start_state) { "Foo:\nBar:" }

          it 'causes a compile error' do
            subject[:compile_error].should be_true
          end
        end

        describe 'matching a leaf node' do
          describe 'and a leaf node' do
            let(:start_state) { "Foo:\nBar:" }

            it 'applies the rule' do
              subject[:exit_status].should == 1
              subject[:end_state].should == parse_state("#{start_state}\nBaz:")
            end
          end

          describe 'and a node with children' do
            let(:start_state) { "Foo:\nBar:\n  Qux:" }

            it 'does not apply the rule' do
              subject[:exit_status].should == 1
              subject[:end_state].should == parse_state(start_state)
            end
          end

          describe 'and a node with a value' do
            let(:start_state) { "Foo:\nBar: 5" }

            it 'does not apply the rule' do
              subject[:exit_status].should == 1
              subject[:end_state].should == parse_state(start_state)
            end
          end
        end

        describe 'matching a node with children' do
          describe 'and a node with children' do
            # TODO
          end

          describe 'and a node with a value' do
            let(:start_state) { "Foo:\n  Baz:\nBar: 5" }

            it 'does not apply the rule' do
              subject[:exit_status].should == 1
              subject[:end_state].should == parse_state(start_state)
            end
          end
        end

        describe 'matching a node with a value' do
          describe 'and a node with a value' do
            describe 'that are equal integers' do
              let(:start_state) { "Foo: 5\nBar: 5" }

              it 'applies the rule' do
                subject[:exit_status].should == 1
                subject[:end_state].should == parse_state("#{start_state}\nBar:")
              end
            end

            describe 'that are unequal integers' do
              let(:start_state) { "Foo: 4\nBar: 5" }

              it 'does not apply the rule' do
                subject[:exit_status].should == 1
                subject[:end_state].should == parse_state(start_state)
              end
            end

            describe 'that are equal decimals' do
              let(:start_state) { "Foo: 5.0\nBar: 5.0" }

              it 'applies the rule' do
                subject[:exit_status].should == 1
                subject[:end_state].should == parse_state("#{start_state}\nBar:")
              end
            end

            describe 'that are unequal decimals' do
              let(:start_state) { "Foo: 4.0\nBar: 5.0" }

              it 'does not apply the rule' do
                subject[:exit_status].should == 1
                subject[:end_state].should == parse_state(start_state)
              end
            end

            describe 'that are an integer and a decimal' do
              let(:start_state) { "Foo: 5\nBar: 5.0" }

              it 'does not apply the rule' do
                subject[:exit_status].should == 1
                subject[:end_state].should == parse_state(start_state)
              end
            end
          end
        end

        describe 'and a removing condition' do
          it 'does not allow the variable to be used in a code segment'

          describe 'matching a leaf node' do
            describe 'and a leaf node' do
              describe 'and a leaf node' do
                it 'applies the rule'
              end

              describe 'and a node with children' do
                it 'does not apply the rule'
              end

              describe 'and a node with a value' do
                it 'does not apply the rule'
              end
            end

            describe 'and a node with children' do
              describe 'and a leaf node' do
                it 'does not apply the rule'
              end

              describe 'and a node with children' do
                it 'does not apply the rule'
              end

              describe 'and a node with a value' do
                it 'does not apply the rule'
              end
            end

            describe 'and a node with a value' do
              describe 'and a leaf node' do
                it 'does not apply the rule'
              end

              describe 'and a node with children' do
                it 'does not apply the rule'
              end

              describe 'and a node with a value' do
                it 'does not apply the rule'
              end
            end
          end

          describe 'matching a node with children' do
            describe 'and a node with children' do
              describe 'and a leaf node' do
                it 'does not apply the rule'
              end

              describe 'and a node with children' do
                # TODO
              end

              describe 'and a node with a value' do
                it 'does not apply the rule'
              end
            end

            describe 'and a node with a value' do
              describe 'and a leaf node' do
                it 'does not apply the rule'
              end

              describe 'and a node with children' do
                it 'does not apply the rule'
              end

              describe 'and a node with a value' do
                it 'does not apply the rule'
              end
            end
          end

          describe 'matching a node with a value' do
            describe 'and a node with a value' do
              describe 'and a leaf node' do
                it 'does not apply the rule'
              end

              describe 'and a node with children' do
                it 'does not apply the rule'
              end

              describe 'and a node with a value' do
                describe 'that are equal integers' do
                  it 'applies the rule'
                end

                describe 'that are unequal integers' do
                  it 'does not apply the rule'
                end

                describe 'that are equal decimals' do
                  it 'applies the rule'
                end

                describe 'that are unequal decimals' do
                  it 'does not apply the rule'
                end

                describe 'that are integers and decimals' do
                  it 'does not apply the rule'
                end
              end
            end
          end

          describe 'and a creating condition' do
            it 'does not allow the variable to be used in a code segment'

            describe 'matching a leaf node' do
              describe 'and a leaf node' do
                describe 'and a leaf node' do
                  it 'applies the rule'
                end

                describe 'and a node with children' do
                  it 'does not apply the rule'
                end

                describe 'and a node with a value' do
                  it 'does not apply the rule'
                end
              end

              describe 'and a node with children' do
                describe 'and a leaf node' do
                  it 'does not apply the rule'
                end

                describe 'and a node with children' do
                  it 'does not apply the rule'
                end

                describe 'and a node with a value' do
                  it 'does not apply the rule'
                end
              end

              describe 'and a node with a value' do
                describe 'and a leaf node' do
                  it 'does not apply the rule'
                end

                describe 'and a node with children' do
                  it 'does not apply the rule'
                end

                describe 'and a node with a value' do
                  it 'does not apply the rule'
                end
              end
            end

            describe 'matching a node with children' do
              describe 'and a node with children' do
                describe 'and a leaf node' do
                  it 'does not apply the rule'
                end

                describe 'and a node with children' do
                  # TODO
                end

                describe 'and a node with a value' do
                  it 'does not apply the rule'
                end
              end

              describe 'and a node with a value' do
                describe 'and a leaf node' do
                  it 'does not apply the rule'
                end

                describe 'and a node with children' do
                  it 'does not apply the rule'
                end

                describe 'and a node with a value' do
                  it 'does not apply the rule'
                end
              end
            end

            describe 'matching a node with a value' do
              describe 'and a node with a value' do
                describe 'and a leaf node' do
                  it 'does not apply the rule'
                end

                describe 'and a node with children' do
                  it 'does not apply the rule'
                end

                describe 'and a node with a value' do
                  describe 'that are equal integers' do
                    it 'applies the rule'
                  end

                  describe 'that are unequal integers' do
                    it 'does not apply the rule'
                  end

                  describe 'that are equal decimals' do
                    it 'applies the rule'
                  end

                  describe 'that are unequal decimals' do
                    it 'does not apply the rule'
                  end

                  describe 'that are integers and decimals' do
                    it 'does not apply the rule'
                  end
                end
              end
            end

            describe 'and a preventing condition' do
              it 'does not allow the variable to be used in a code segment'

              describe 'matching a leaf node' do
                describe 'and a leaf node' do
                  describe 'and a leaf node' do
                    describe 'and a leaf node' do
                      it 'does not apply the rule'
                    end

                    describe 'and a node with children' do
                      it 'applies the rule'
                    end

                    describe 'and a node with a value' do
                      it 'applies the rule'
                    end
                  end

                  describe 'and a node with children' do
                    describe 'and a leaf node' do
                      it 'does not apply the rule'
                    end

                    describe 'and a node with children' do
                      it 'does not apply the rule'
                    end

                    describe 'and a node with a value' do
                      it 'does not apply the rule'
                    end
                  end

                  describe 'and a node with a value' do
                    describe 'and a leaf node' do
                      it 'does not apply the rule'
                    end

                    describe 'and a node with children' do
                      it 'does not apply the rule'
                    end

                    describe 'and a node with a value' do
                      it 'does not apply the rule'
                    end
                  end
                end

                describe 'and a node with children' do
                  describe 'and a leaf node' do
                    describe 'and a leaf node' do
                      it 'does not apply the rule'
                    end

                    describe 'and a node with children' do
                      it 'does not apply the rule'
                    end

                    describe 'and a node with a value' do
                      it 'does not apply the rule'
                    end
                  end

                  describe 'and a node with children' do
                    describe 'and a leaf node' do
                      it 'does not apply the rule'
                    end

                    describe 'and a node with children' do
                      it 'does not apply the rule'
                    end

                    describe 'and a node with a value' do
                      it 'does not apply the rule'
                    end
                  end

                  describe 'and a node with a value' do
                    describe 'and a leaf node' do
                      it 'does not apply the rule'
                    end

                    describe 'and a node with children' do
                      it 'does not apply the rule'
                    end

                    describe 'and a node with a value' do
                      it 'does not apply the rule'
                    end
                  end
                end

                describe 'and a node with a value' do
                  describe 'and a leaf node' do
                    describe 'and a leaf node' do
                      it 'does not apply the rule'
                    end

                    describe 'and a node with children' do
                      it 'does not apply the rule'
                    end

                    describe 'and a node with a value' do
                      it 'does not apply the rule'
                    end
                  end

                  describe 'and a node with children' do
                    describe 'and a leaf node' do
                      it 'does not apply the rule'
                    end

                    describe 'and a node with children' do
                      it 'does not apply the rule'
                    end

                    describe 'and a node with a value' do
                      it 'does not apply the rule'
                    end
                  end

                  describe 'and a node with a value' do
                    describe 'and a leaf node' do
                      it 'does not apply the rule'
                    end

                    describe 'and a node with children' do
                      it 'does not apply the rule'
                    end

                    describe 'and a node with a value' do
                      it 'does not apply the rule'
                    end
                  end
                end
              end

              describe 'matching a node with children' do
                describe 'and a node with children' do
                  describe 'and a leaf node' do
                    describe 'and a leaf node' do
                      it 'does not apply the rule'
                    end

                    describe 'and a node with children' do
                      it 'does not apply the rule'
                    end

                    describe 'and a node with a value' do
                      it 'does not apply the rule'
                    end
                  end

                  describe 'and a node with children' do
                    describe 'and a leaf node' do
                      # TODO
                    end

                    describe 'and a node with children' do
                      # TODO
                    end

                    describe 'and a node with a value' do
                      # TODO
                    end
                  end

                  describe 'and a node with a value' do
                    describe 'and a leaf node' do
                      it 'does not apply the rule'
                    end

                    describe 'and a node with children' do
                      it 'does not apply the rule'
                    end

                    describe 'and a node with a value' do
                      it 'does not apply the rule'
                    end
                  end
                end

                describe 'and a node with a value' do
                  describe 'and a leaf node' do
                    describe 'and a leaf node' do
                      it 'does not apply the rule'
                    end

                    describe 'and a node with children' do
                      it 'does not apply the rule'
                    end

                    describe 'and a node with a value' do
                      it 'does not apply the rule'
                    end
                  end

                  describe 'and a node with children' do
                    describe 'and a leaf node' do
                      it 'does not apply the rule'
                    end

                    describe 'and a node with children' do
                      it 'does not apply the rule'
                    end

                    describe 'and a node with a value' do
                      it 'does not apply the rule'
                    end
                  end

                  describe 'and a node with a value' do
                    describe 'and a leaf node' do
                      it 'does not apply the rule'
                    end

                    describe 'and a node with children' do
                      it 'does not apply the rule'
                    end

                    describe 'and a node with a value' do
                      it 'does not apply the rule'
                    end
                  end
                end
              end

              describe 'matching a node with a value' do
                describe 'and a node with a value' do
                  describe 'and a leaf node' do
                    describe 'and a leaf node' do
                      it 'does not apply the rule'
                    end

                    describe 'and a node with children' do
                      it 'does not apply the rule'
                    end

                    describe 'and a node with a value' do
                      it 'does not apply the rule'
                    end
                  end

                  describe 'and a node with children' do
                    describe 'and a leaf node' do
                      it 'does not apply the rule'
                    end

                    describe 'and a node with children' do
                      it 'does not apply the rule'
                    end

                    describe 'and a node with a value' do
                      it 'does not apply the rule'
                    end
                  end

                  describe 'and a node with a value' do
                    describe 'and a leaf node' do
                      # TODO
                    end

                    describe 'and a node with children' do
                      # TODO
                    end

                    describe 'and a node with a value' do
                      # TODO
                    end
                  end
                end
              end
            end
          end

          describe 'and a preventing condition' do
            it 'does not allow the variable to be used in a code segment'

            describe 'matching a leaf node' do
              describe 'and a leaf node' do
                describe 'and a leaf node' do
                  describe 'and a leaf node' do
                    it 'does not apply the rule'
                  end

                  describe 'and a node with children' do
                    it 'applies the rule'
                  end

                  describe 'and a node with a value' do
                    it 'applies the rule'
                  end
                end

                describe 'and a node with children' do
                  describe 'and a leaf node' do
                    it 'does not apply the rule'
                  end

                  describe 'and a node with children' do
                    it 'does not apply the rule'
                  end

                  describe 'and a node with a value' do
                    it 'does not apply the rule'
                  end
                end

                describe 'and a node with a value' do
                  describe 'and a leaf node' do
                    it 'does not apply the rule'
                  end

                  describe 'and a node with children' do
                    it 'does not apply the rule'
                  end

                  describe 'and a node with a value' do
                    it 'does not apply the rule'
                  end
                end
              end

              describe 'and a node with children' do
                describe 'and a leaf node' do
                  describe 'and a leaf node' do
                    it 'does not apply the rule'
                  end

                  describe 'and a node with children' do
                    it 'does not apply the rule'
                  end

                  describe 'and a node with a value' do
                    it 'does not apply the rule'
                  end
                end

                describe 'and a node with children' do
                  describe 'and a leaf node' do
                    it 'does not apply the rule'
                  end

                  describe 'and a node with children' do
                    it 'does not apply the rule'
                  end

                  describe 'and a node with a value' do
                    it 'does not apply the rule'
                  end
                end

                describe 'and a node with a value' do
                  describe 'and a leaf node' do
                    it 'does not apply the rule'
                  end

                  describe 'and a node with children' do
                    it 'does not apply the rule'
                  end

                  describe 'and a node with a value' do
                    it 'does not apply the rule'
                  end
                end
              end

              describe 'and a node with a value' do
                describe 'and a leaf node' do
                  describe 'and a leaf node' do
                    it 'does not apply the rule'
                  end

                  describe 'and a node with children' do
                    it 'does not apply the rule'
                  end

                  describe 'and a node with a value' do
                    it 'does not apply the rule'
                  end
                end

                describe 'and a node with children' do
                  describe 'and a leaf node' do
                    it 'does not apply the rule'
                  end

                  describe 'and a node with children' do
                    it 'does not apply the rule'
                  end

                  describe 'and a node with a value' do
                    it 'does not apply the rule'
                  end
                end

                describe 'and a node with a value' do
                  describe 'and a leaf node' do
                    it 'does not apply the rule'
                  end

                  describe 'and a node with children' do
                    it 'does not apply the rule'
                  end

                  describe 'and a node with a value' do
                    it 'does not apply the rule'
                  end
                end
              end
            end

            describe 'matching a node with children' do
              describe 'and a node with children' do
                describe 'and a leaf node' do
                  describe 'and a leaf node' do
                    it 'does not apply the rule'
                  end

                  describe 'and a node with children' do
                    it 'does not apply the rule'
                  end

                  describe 'and a node with a value' do
                    it 'does not apply the rule'
                  end
                end

                describe 'and a node with children' do
                  describe 'and a leaf node' do
                    # TODO
                  end

                  describe 'and a node with children' do
                    # TODO
                  end

                  describe 'and a node with a value' do
                    # TODO
                  end
                end

                describe 'and a node with a value' do
                  describe 'and a leaf node' do
                    it 'does not apply the rule'
                  end

                  describe 'and a node with children' do
                    it 'does not apply the rule'
                  end

                  describe 'and a node with a value' do
                    it 'does not apply the rule'
                  end
                end
              end

              describe 'and a node with a value' do
                describe 'and a leaf node' do
                  describe 'and a leaf node' do
                    it 'does not apply the rule'
                  end

                  describe 'and a node with children' do
                    it 'does not apply the rule'
                  end

                  describe 'and a node with a value' do
                    it 'does not apply the rule'
                  end
                end

                describe 'and a node with children' do
                  describe 'and a leaf node' do
                    it 'does not apply the rule'
                  end

                  describe 'and a node with children' do
                    it 'does not apply the rule'
                  end

                  describe 'and a node with a value' do
                    it 'does not apply the rule'
                  end
                end

                describe 'and a node with a value' do
                  describe 'and a leaf node' do
                    it 'does not apply the rule'
                  end

                  describe 'and a node with children' do
                    it 'does not apply the rule'
                  end

                  describe 'and a node with a value' do
                    it 'does not apply the rule'
                  end
                end
              end
            end

            describe 'matching a node with a value' do
              describe 'and a node with a value' do
                describe 'and a leaf node' do
                  describe 'and a leaf node' do
                    it 'does not apply the rule'
                  end

                  describe 'and a node with children' do
                    it 'does not apply the rule'
                  end

                  describe 'and a node with a value' do
                    it 'does not apply the rule'
                  end
                end

                describe 'and a node with children' do
                  describe 'and a leaf node' do
                    it 'does not apply the rule'
                  end

                  describe 'and a node with children' do
                    it 'does not apply the rule'
                  end

                  describe 'and a node with a value' do
                    it 'does not apply the rule'
                  end
                end

                describe 'and a node with a value' do
                  describe 'and a leaf node' do
                    # TODO
                  end

                  describe 'and a node with children' do
                    # TODO
                  end

                  describe 'and a node with a value' do
                    # TODO
                  end
                end
              end
            end
          end
        end

        describe 'and a creating condition' do
          it 'does not allow the variable to be used in a code segment'

          describe 'matching a leaf node' do
            describe 'and a leaf node' do
              it 'applies the rule'
            end

            describe 'and a node with children' do
              it 'does not apply the rule'
            end

            describe 'and a node with a value' do
              it 'does not apply the rule'
            end
          end

          describe 'matching a node with children' do
            describe 'and a node with children' do
              # TODO
            end

            describe 'and a node with a value' do
              it 'does not apply the rule'
            end
          end

          describe 'matching a node with a value' do
            describe 'and a node with a value' do
              describe 'that are equal integers' do
                it 'applies the rule'
              end

              describe 'that are unequal integers' do
                it 'does not apply the rule'
              end

              describe 'that are equal decimals' do
                it 'applies the rule'
              end

              describe 'that are unequal decimals' do
                it 'does not apply the rule'
              end

              describe 'that are an integer and a decimal' do
                it 'does not apply the rule'
              end
            end
          end

          describe 'and a preventing condition' do
            it 'does not allow the variable to be used in a code segment'

            describe 'matching a leaf node' do
              describe 'and a leaf node' do
                describe 'and a leaf node' do
                  it 'does not apply the rule'
                end

                describe 'and a node with children' do
                  it 'applies the rule'
                end

                describe 'and a node with a value' do
                  it 'applies the rule'
                end
              end

              describe 'and a node with children' do
                describe 'and a leaf node' do
                  it 'does not apply the rule'
                end

                describe 'and a node with children' do
                  it 'does not apply the rule'
                end

                describe 'and a node with a value' do
                  it 'does not apply the rule'
                end
              end

              describe 'and a node with a value' do
                describe 'and a leaf node' do
                  it 'does not apply the rule'
                end

                describe 'and a node with children' do
                  it 'does not apply the rule'
                end

                describe 'and a node with a value' do
                  it 'does not apply the rule'
                end
              end
            end

            describe 'matching a node with children' do
              describe 'and a node with children' do
                describe 'and a leaf node' do
                  # TODO
                end

                describe 'and a node with children' do
                  # TODO
                end

                describe 'and a node with a value' do
                  # TODO
                end
              end

              describe 'and a node with a value' do
                describe 'and a leaf node' do
                  it 'does not apply the rule'
                end

                describe 'and a node with children' do
                  it 'does not apply the rule'
                end

                describe 'and a node with a value' do
                  it 'does not apply the rule'
                end
              end
            end

            describe 'matching a node with a value' do
              describe 'and a node with a value' do
                describe 'and a leaf node' do
                  # TODO
                end

                describe 'and a node with children' do
                  # TODO
                end

                describe 'and a node with a value' do
                  # TODO
                end
              end
            end
          end
        end

        describe 'and a preventing condition' do
          it 'does not allow the variable to be used in a code segment'

          describe 'matching a leaf node' do
            describe 'and a leaf node' do
              describe 'and a leaf node' do
                it 'does not apply the rule'
              end

              describe 'and a node with children' do
                it 'applies the rule'
              end

              describe 'and a node with a value' do
                it 'applies the rule'
              end
            end

            describe 'and a node with children' do
              describe 'and a leaf node' do
                it 'does not apply the rule'
              end

              describe 'and a node with children' do
                it 'does not apply the rule'
              end

              describe 'and a node with a value' do
                it 'does not apply the rule'
              end
            end

            describe 'and a node with a value' do
              describe 'and a leaf node' do
                it 'does not apply the rule'
              end

              describe 'and a node with children' do
                it 'does not apply the rule'
              end

              describe 'and a node with a value' do
                it 'does not apply the rule'
              end
            end
          end

          describe 'matching a node with children' do
            describe 'and a node with children' do
              describe 'and a leaf node' do
                # TODO
              end

              describe 'and a node with children' do
                # TODO
              end

              describe 'and a node with a value' do
                # TODO
              end
            end

            describe 'and a node with a value' do
              describe 'and a leaf node' do
                it 'does not apply the rule'
              end

              describe 'and a node with children' do
                it 'does not apply the rule'
              end

              describe 'and a node with a value' do
                it 'does not apply the rule'
              end
            end
          end

          describe 'matching a node with a value' do
            describe 'and a node with a value' do
              describe 'and a leaf node' do
                # TODO
              end

              describe 'and a node with children' do
                # TODO
              end

              describe 'and a node with a value' do
                # TODO
              end
            end
          end
        end
      end

      describe 'and a removing condition' do
        it 'does not allow the variable to be used in a code segment'

        describe 'matching a leaf node' do
          describe 'and a leaf node' do
            it 'applies the rule'
          end

          describe 'and a node with children' do
            it 'does not apply the rule'
          end

          describe 'and a node with a value' do
            it 'does not apply the rule'
          end
        end

        describe 'matching a node with children' do
          describe 'and a node with children' do
            # TODO
          end

          describe 'and a node with a value' do
            it 'does not apply the rule'
          end
        end

        describe 'matching a node with a value' do
          describe 'and a node with a value' do
            describe 'that are equal integers' do
              it 'applies the rule'
            end

            describe 'that are unequal integers' do
              it 'does not apply the rule'
            end

            describe 'that are equal decimals' do
              it 'applies the rule'
            end

            describe 'that are unequal decimals' do
              it 'does not apply the rule'
            end

            describe 'that are an integer and a decimal' do
              it 'does not apply the rule'
            end
          end
        end

        describe 'and a creating condition' do
          it 'does not allow the variable to be used in a code segment'

          describe 'matching a leaf node' do
            describe 'and a leaf node' do
              it 'applies the rule'
            end

            describe 'and a node with children' do
              it 'does not apply the rule'
            end

            describe 'and a node with a value' do
              it 'does not apply the rule'
            end
          end

          describe 'matching a node with children' do
            describe 'and a node with children' do
              # TODO
            end

            describe 'and a node with a value' do
              it 'does not apply the rule'
            end
          end

          describe 'matching a node with a value' do
            describe 'and a node with a value' do
              describe 'that are equal integers' do
                it 'applies the rule'
              end

              describe 'that are unequal integers' do
                it 'does not apply the rule'
              end

              describe 'that are equal decimals' do
                it 'applies the rule'
              end

              describe 'that are unequal decimals' do
                it 'does not apply the rule'
              end

              describe 'that are an integer and a decimal' do
                it 'does not apply the rule'
              end
            end
          end

          describe 'and a preventing condition' do
            it 'does not allow the variable to be used in a code segment'

            describe 'matching a leaf node' do
              describe 'and a leaf node' do
                describe 'and a leaf node' do
                  it 'does not apply the rule'
                end

                describe 'and a node with children' do
                  it 'applies the rule'
                end

                describe 'and a node with a value' do
                  it 'applies the rule'
                end
              end

              describe 'and a node with children' do
                describe 'and a leaf node' do
                  it 'does not apply the rule'
                end

                describe 'and a node with children' do
                  it 'does not apply the rule'
                end

                describe 'and a node with a value' do
                  it 'does not apply the rule'
                end
              end

              describe 'and a node with a value' do
                describe 'and a leaf node' do
                  it 'does not apply the rule'
                end

                describe 'and a node with children' do
                  it 'does not apply the rule'
                end

                describe 'and a node with a value' do
                  it 'does not apply the rule'
                end
              end
            end

            describe 'matching a node with children' do
              describe 'and a node with children' do
                describe 'and a leaf node' do
                  # TODO
                end

                describe 'and a node with children' do
                  # TODO
                end

                describe 'and a node with a value' do
                  # TODO
                end
              end

              describe 'and a node with a value' do
                describe 'and a leaf node' do
                  it 'does not apply the rule'
                end

                describe 'and a node with children' do
                  it 'does not apply the rule'
                end

                describe 'and a node with a value' do
                  it 'does not apply the rule'
                end
              end
            end

            describe 'matching a node with a value' do
              describe 'and a node with a value' do
                describe 'and a leaf node' do
                  # TODO
                end

                describe 'and a node with children' do
                  # TODO
                end

                describe 'and a node with a value' do
                  # TODO
                end
              end
            end
          end
        end
      end

      describe 'and a creating condition' do
        it 'allows the variable to be used in a code segment'

        describe 'matching a leaf node' do
          it 'applies the rule'
          it 'does not link the nodes'
        end

        describe 'matching a node with children' do
          it 'applies the rule'
          it 'does not link the nodes'
        end

        describe 'matching a node with a value' do
          it 'applies the rule'
          it 'does not link the nodes'
        end

        describe 'and a preventing condition' do
          it 'allows the variable to be used in a code segment'

          describe 'matching a leaf node' do
            describe 'and a leaf node' do
              it 'does not apply the rule'
            end

            describe 'and a node with children' do
              it 'applies the rule'
            end

            describe 'and a node with a value' do
              it 'applies the rule'
            end
          end

          describe 'matching a node with children' do
            describe 'and a leaf node' do
              it 'applies the rule'
            end

            describe 'and a node with children' do
              # TODO
            end

            describe 'and a node with a value' do
              it 'applies the rule'
            end
          end

          describe 'matching a node with a value' do
            describe 'and a leaf node' do
              it 'applies the rule'
            end

            describe 'and a node with children' do
              it 'applies the rule'
            end

            describe 'and a node with a value' do
              # TODO
            end
          end
        end
      end

      describe 'and a preventing condition' do
        it 'allows the variable to be used in a code segment'

        describe 'matching a leaf node' do
          describe 'and a leaf node' do
            it 'does not apply the rule'
          end

          describe 'and a node with children' do
            it 'applies the rule'
          end

          describe 'and a node with a value' do
            it 'applies the rule'
          end
        end

        describe 'matching a node with children' do
          describe 'and a leaf node' do
            it 'applies the rule'
          end

          describe 'and a node with children' do
            # TODO
          end

          describe 'and a node with a value' do
            it 'applies the rule'
          end
        end

        describe 'matching a node with a value' do
          describe 'and a leaf node' do
            it 'applies the rule'
          end

          describe 'and a node with children' do
            it 'applies the rule'
          end

          describe 'and a node with a value' do
            # TODO
          end
        end
      end
    end

    describe 'referenced in a removing condition' do
      it 'allows the variable to be used in a code segment'

      describe 'matching a leaf node' do
        it 'applies the rule'
      end

      describe 'matching a node with children' do
        it 'applies the rule'
      end

      describe 'matching a node with a value' do
        it 'applies the rule'
      end

      describe 'and another removing condition' do
        it 'does not allow the variable to be used in a code segment'

        describe 'matching a leaf node' do
          describe 'and a leaf node' do
            it 'applies the rule'
          end

          describe 'and a node with children' do
            it 'does not apply the rule'
          end

          describe 'and a node with a value' do
            it 'does not apply the rule'
          end
        end

        describe 'matching a node with children' do
          describe 'and a node with children' do
            # TODO
          end

          describe 'and a node with a value' do
            it 'does not apply the rule'
          end
        end

        describe 'matching a node with a value' do
          describe 'and a node with a value' do
            describe 'that are equal integers' do
              it 'applies the rule'
            end

            describe 'that are unequal integers' do
              it 'does not apply the rule'
            end

            describe 'that are equal decimals' do
              it 'applies the rule'
            end

            describe 'that are unequal decimals' do
              it 'does not apply the rule'
            end

            describe 'that are an integer and a decimal' do
              it 'does not apply the rule'
            end
          end
        end
      end

      describe 'and a creating condition' do
        it 'allows the variable to be used in a code segment'

        describe 'matching a leaf node' do
          it 'applies the rule'
        end

        describe 'matching a node with children' do
          it 'applies the rule'
        end

        describe 'matching a node with a value' do
          it 'applies the rule'
        end

        describe 'and a preventing condition' do
          it 'allows the variable to be used in a code segment'

          describe 'matching a leaf node' do
            describe 'and a leaf node' do
              it 'does not apply the rule'
            end

            describe 'and a node with children' do
              it 'applies the rule'
            end

            describe 'and a node with a value' do
              it 'applies the rule'
            end
          end

          describe 'matching a node with children' do
            describe 'and a leaf node' do
              it 'applies the rule'
            end

            describe 'and a node with children' do
              # TODO
            end

            describe 'and a node with a value' do
              it 'applies the rule'
            end
          end

          describe 'matching a node with a value' do
            describe 'and a leaf node' do
              it 'applies the rule'
            end

            describe 'and a node with children' do
              it 'applies the rule'
            end

            describe 'and a node with a value' do
              # TODO
            end
          end
        end
      end

      describe 'and a preventing condition' do
        it 'allows the variable to be used in a code segment'

        describe 'matching a leaf node' do
          describe 'and a leaf node' do
            it 'does not apply the rule'
          end

          describe 'and a node with children' do
            it 'applies the rule'
          end

          describe 'and a node with a value' do
            it 'applies the rule'
          end
        end

        describe 'matching a node with children' do
          describe 'and a leaf node' do
            it 'applies the rule'
          end

          describe 'and a node with children' do
            # TODO
          end

          describe 'and a node with a value' do
            it 'applies the rule'
          end
        end

        describe 'matching a node with a value' do
          describe 'and a leaf node' do
            it 'applies the rule'
          end

          describe 'and a node with children' do
            it 'applies the rule'
          end

          describe 'and a node with a value' do
            # TODO
          end
        end
      end
    end

    describe 'referenced in a creating condition' do
      it 'applies the rule'
      it 'allows the variable to be used in a code segment'

      describe 'and another creating condition' do
        it 'applies the rule'
        it 'allows the variable to be used in a code segment'
        it 'does not link the nodes'
      end

      describe 'and a preventing condition' do
        it 'causes a compile error'
      end
    end

    describe 'referenced in a preventing condition' do
      it 'causes a compile error'

      describe 'and another preventing condition' do
        it 'causes a compile error'
      end
    end

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

      describe 'matching leaf nodes' do
        it 'allows the rule to match' do
          result = run_program :rules => rules, :start_state => "Foo:\nBar:"
          result[:exit_status].should == 1
          result[:end_state].should == parse_state('Bar:')
        end
      end

      describe 'matching a leaf node and a value' do
        it 'prevents the rule from matching' do
          result = run_program :rules => rules, :start_state => "Foo:\nBar: 5"
          result[:exit_status].should == 1
          result[:end_state].should == parse_state("Foo:\nBar: 5")
        end
      end

      describe 'matching a leaf node and a node\'s children' do
        it 'prevents the rule from matching' do
          result = run_program :rules => rules, :start_state => "Foo:\nBar:\n  Baz:"
          result[:exit_status].should == 1
          result[:end_state].should == parse_state("Foo:\nBar:\n  Baz:")
        end
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

    describe 'used in a preventing condition' do
      # TODO
    end

    describe 'used in a code segment' do
      describe 'referenced in a matching condition' do
        it 'allows the variable to be accessed' do
          rules = <<-EOS
            Foo: X
            !Bar:
            +Bar:
            < $X->integer_value++;
          EOS
          result = run_program :rules => rules, :start_state => 'Foo: 5'
          result[:exit_status].should == 1
          result[:end_state].should == parse_state("Foo: 6\nBar:")
        end

        describe 'and another matching condition' do
          it 'does not allow the variable to be accessed' do
            rules = <<-EOS
              Foo: X
              Bar: X
              < $X->integer_value++;
            EOS
            result = run_program :rules => rules, :start_state => "Foo: 5\nBar: 5"
            result[:gcc_error].should be_true
          end
        end

        describe 'and a removing condition' do
          it 'does not allow the variable to be accessed' do
            rules = <<-EOS
              Foo: X
              -Bar: X
              < $X->integer_value++;
            EOS
            result = run_program :rules => rules, :start_state => "Foo: 5\nBar: 5"
            result[:gcc_error].should be_true
          end

          describe 'and a creating condition' do
            it 'does not allow the variable to be accessed' do
              rules = <<-EOS
                Foo: X
                -Bar: X
                +Baz: X
                < $X->integer_value++;
              EOS
              result = run_program :rules => rules, :start_state => "Foo: 5\nBar: 5"
              result[:gcc_error].should be_true
            end

            describe 'and a preventing condition' do
              it 'does not allow the variable to be accessed' do
                rules = <<-EOS
                  Foo: X
                  -Bar: X
                  +Baz: X
                  !Qux: X
                  < $X->integer_value++;
                EOS
                result = run_program :rules => rules, :start_state => "Foo: 5\nBar: 5"
                result[:gcc_error].should be_true
              end
            end
          end

          describe 'and a preventing condition' do
            it 'does not allow the variable to be accessed' do
              rules = <<-EOS
                Foo: X
                -Bar: X
                !Baz: X
                < $X->integer_value++;
              EOS
              result = run_program :rules => rules, :start_state => "Foo: 5\nBar: 5"
              result[:gcc_error].should be_true
            end
          end
        end

        describe 'and a creating condition' do
          it 'allows the variable to be accessed' do
            rules = <<-EOS
              Foo: X
              !Bar:
              +Bar: X
              < $X->integer_value++;
            EOS
            result = run_program :rules => rules, :start_state => 'Foo: 5'
            result[:exit_status].should == 1
            result[:end_state].should == parse_state("Foo: 6\nBar: 6")
          end

          it 'does not link the nodes' do
            rules = <<-EOS
              Foo: X
              !Bar:
              +Bar: X
              < $X->integer_value++;

              Bar: X
              !Baz:
              +Baz:
              < $X->integer_value++;
            EOS
            result = run_program :rules => rules, :start_state => 'Foo: 5'
            result[:exit_status].should == 1
            result[:end_state].should == parse_state("Foo: 6\nBar: 7\nBaz:")
          end

          describe 'and a preventing condition' do
            it 'allows the variable to be accessed' do
              rules = <<-EOS
                Foo: X
                !Bar: X
                +Bar: X
                < $X->integer_value++;
              EOS
              result = run_program :rules => rules, :start_state => 'Foo: 5'
              result[:exit_status].should == 1
              result[:end_state].should == parse_state("Foo: 6\nBar: 6")
            end
          end
        end

        describe 'and a preventing condition' do
          it 'allows the variable to be accessed' do
            rules = <<-EOS
              Foo: X
              !Bar: X
              !Baz:
              +Baz:
              < $X->integer_value++;
            EOS
            result = run_program :rules => rules, :start_state => 'Foo: 5'
            result[:exit_status].should == 1
            result[:end_state].should == parse_state("Foo: 6\nBaz:")
          end
        end
      end

      describe 'referenced in a removing condition' do
        it 'allows the variable to be accessed' do
          rules = <<-EOS
            %{
              #include <stdio.h>
            %}

            -Foo: X
            < printf("%d", $X->integer_value);
          EOS
          result = run_program :rules => rules, :start_state => 'Foo: 5'
          result[:exit_status].should == 1
          result[:stdout].should == '5'
          result[:end_state].should == parse_state('')
        end

        describe 'and another removing condition' do
          it 'does not allow the variable to be accessed' do
            rules = <<-EOS
              -Foo: X
              -Bar: X
              < $X->integer_value++;
            EOS
            result = run_program :rules => rules, :start_state => "Foo: 5\nBar: 5"
            result[:gcc_error].should be_true
          end
        end

        describe 'and a creating condition' do
          it 'allows the variable to be accessed' do
            rules = <<-EOS
              -Foo: X
              +Bar: X
              < $X->integer_value++;
            EOS
            result = run_program :rules => rules, :start_state => 'Foo: 5'
            result[:exit_status].should == 1
            result[:end_state].should == parse_state('Bar: 6')
          end

          describe 'and a preventing condition' do
            it 'allows the variable to be accessed' do
              rules = <<-EOS
                -Foo: X
                +Bar: X
                !Baz: X
                < $X->integer_value++;
              EOS
              result = run_program :rules => rules, :start_state => 'Foo: 5'
              result[:exit_status].should == 1
              result[:end_state].should == parse_state('Bar: 6')
            end
          end
        end

        describe 'and a preventing condition' do
          it 'allows the variable to be accessed' do
            rules = <<-EOS
              %{
                #include <stdio.h>
              %}

              -Foo: X
              !Bar: X
              < printf("%d", $X->integer_value);
            EOS
            result = run_program :rules => rules, :start_state => 'Foo: 5'
            result[:exit_status].should == 1
            result[:stdout].should == '5'
            result[:end_state].should == parse_state('')
          end
        end
      end

      describe 'referenced in a creating condition' do
        it 'allows the variable to be accessed' do
          rules = <<-EOS
            !Foo:
            +Foo: X
            < $X->value_type = integer;
            < $X->integer_value = 5;
          EOS
          result = run_program :rules => rules, :start_state => ''
          result[:exit_status].should == 1
          result[:end_state].should == parse_state('Foo: 5')
        end

        describe 'and another creating condition' do
          it 'allows the variable to be accessed' do
            rules = <<-EOS
              !Foo:
              +Foo: X
              +Bar: X
              < $X->value_type = integer;
              < $X->integer_value = 5;
            EOS
            result = run_program :rules => rules, :start_state => ''
            result[:exit_status].should == 1
            result[:end_state].should == parse_state("Foo: 5\nBar: 5")
          end

          it 'does not link the nodes' do
            rules = <<-EOS
              !Foo:
              +Foo: X
              +Bar: X
              < $X->value_type = integer;
              < $X->integer_value = 5;

              Bar: X
              !Baz:
              +Baz:
              < $X->integer_value++;
            EOS
            result = run_program :rules => rules, :start_state => ''
            result[:exit_status].should == 1
            result[:end_state].should == parse_state("Foo: 5\nBar: 6\nBaz:")
          end
        end

        describe 'and a preventing condition' do
          it 'allows the variable to be accessed' do
            rules = <<-EOS
              !Foo: X
              +Foo: X
              < $X->value_type = integer;
              < $X->integer_value = 5;
            EOS
            result = run_program :rules => rules, :start_state => ''
            result[:exit_status].should == 1
            result[:end_state].should == parse_state('Foo: 5')
          end
        end
      end

      describe 'referenced in a preventing condition' do
        it 'does not allow the variable to be accessed' do
          rules = <<-EOS
            !Foo: X
            < $X->integer_value++;
          EOS
          result = run_program :rules => rules, :start_state => ''
          result[:gcc_error].should be_true
        end
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
