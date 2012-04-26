shared_examples_for 'an okk implementation' do
  let(:header) { "" }
  subject { run_program :rules => rules, :start_state => start_state, :header => header }

  after do
    if subject[:compile_error]
      subject[:exit_status].should be_nil
      subject[:stdout].should be_nil
      subject[:stderr].should be_nil
      subject[:end_state].should be_nil
    else
      subject[:exit_status].should_not be_nil
      subject[:stdout].should_not be_nil
      subject[:stderr].should_not be_nil
      subject[:end_state].should_not be_nil if subject[:exit_status] == 1
      subject[:end_state].should     be_nil if subject[:exit_status] != 1
    end
  end

  def self.it_applies_the_rule end_state
    it 'applies the rule' do
      subject[:end_state].should == parse_state(end_state)
    end
  end

  def self.it_does_not_apply_the_rule
    it 'does not apply the rule' do
      subject[:end_state].should == parse_state(start_state)
    end
  end

  def self.it_causes_a_compile_error
    it 'causes a compile error' do
      subject[:compile_error].should be_true
    end
  end

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
      end

      describe 'with multiple lines of code' do
        let(:rules) { "Foo:\n< printf(\"bar\");\n< exit(0);" }
        it 'executes the code' do
          subject[:exit_status].should == 0
          subject[:stdout].should == "bar"
          subject[:stderr].should == ""
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
      it_causes_a_compile_error
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
      end
    end

    describe 'with invalid code' do
      let(:code) { "not_valid_code;" }
      it_causes_a_compile_error
    end
  end

  describe 'root label' do
    let(:rules) { <<-EOS }
      ^:
        Foo:
      < exit(0);
    EOS

    describe 'when conditions match at the root level' do
      let(:start_state) { <<-EOS }
        Bar:
        Foo:
        Baz:
      EOS

      it 'applies the rule' do
        subject[:exit_status].should == 0
      end
    end

    describe 'when the conditions match below the root level' do
      let(:start_state) { <<-EOS }
        Bar:
          Foo:
        Baz:
      EOS

      it_does_not_apply_the_rule
    end
  end

  describe 'creating nodes' do
    describe 'at the root level' do
      let(:rules) { <<-EOS }
        Foo:
        < exit(0);

        +Foo:
      EOS
      let(:start_state) { "" }

      it 'creates the node' do
        subject[:exit_status].should == 0
      end
    end

    describe 'in a child condition' do
      let(:rules) { <<-EOS }
        Foo:
        < exit(0);

        Bar:
          +Foo:
      EOS

      describe 'with a matching parent' do
        let(:start_state) { "Bar:" }

        it 'creates the node' do
          subject[:exit_status].should == 0
        end
      end

      describe 'without a matching parent' do
        let(:start_state) { "Baz:" }
        it_does_not_apply_the_rule
      end
    end

    describe 'with children' do
      let(:rules) { <<-EOS }
        Foo:
        < exit(0);

        +Bar:
          Foo:
      EOS

      it 'creates the children' do
        subject[:exit_status].should == 0
      end
    end
  end

  describe 'removing nodes' do
    describe 'at the root level' do
      let(:rules) { "-Foo:" }
      let(:start_state) { "Foo:" }
      it_applies_the_rule ""
    end

    describe 'in a child condition' do
      let(:rules) { "Foo:\n  -Bar:" }
      let(:start_state) { "Foo:\n  Bar:" }
      it_applies_the_rule "Foo:"
    end

    describe 'with children' do
      let(:rules) { "-Foo:\n  Bar:" }

      describe 'that match' do
        let(:start_state) { "Foo:\n  Bar:" }
        it_applies_the_rule ""
      end

      describe 'that do not match' do
        let(:start_state) { "Foo:\n  Baz:" }
        it_does_not_apply_the_rule
      end
    end
  end

  describe 'preventing a match' do
    let(:rules) { "!Foo:\n-Bar:" }

    describe 'when a match-preventing condition does not match' do
      let(:start_state) { "Bar:\nBaz:" }
      it_applies_the_rule "Baz:"
    end

    describe 'when a match-preventing condition matches' do
      let(:start_state) { "Bar:\nFoo:" }
      it_does_not_apply_the_rule
    end
  end

  describe 'unordered child conditions' do
    let(:rules) { <<-EOS }
      Foo:
        Bar:
        Baz:
      < exit(0);
    EOS

    describe 'matching unordered child nodes' do
      describe 'that match in order' do
        let(:start_state) { <<-EOS }
          Foo:
            Bar:
            Baz:
        EOS

        it 'applies the rule' do
          subject[:exit_status].should == 0
        end
      end

      describe 'that match out of order' do
        let(:start_state) { <<-EOS }
          Foo:
            Baz:
            Bar:
        EOS

        it 'applies the rule' do
          subject[:exit_status].should == 0
        end
      end
    end

    describe 'matching ordered child nodes' do
      describe 'that match in order' do
        let(:start_state) { <<-EOS }
          Foo::
            Bar:
            Baz:
        EOS

        it 'applies the rule' do
          subject[:exit_status].should == 0
        end
      end

      describe 'that match out of order' do
        let(:start_state) { <<-EOS }
          Foo::
            Baz:
            Bar:
        EOS

        it 'applies the rule' do
          subject[:exit_status].should == 0
        end
      end
    end
  end

  describe 'ordered child conditions' do
    let(:rules) { <<-EOS }
      Foo::
        Bar:
        Baz:
      < exit(0);
    EOS

    describe 'matching unordered child nodes' do
      describe 'that match in order' do
        let(:start_state) { <<-EOS }
          Foo:
            Bar:
            Baz:
        EOS
        it_does_not_apply_the_rule
      end

      describe 'that match out of order' do
        let(:start_state) { <<-EOS }
          Foo:
            Baz:
            Bar:
        EOS
        it_does_not_apply_the_rule
      end
    end

    describe 'matching ordered child nodes' do
      describe 'that match in order' do
        describe 'from the beginning' do
          let(:start_state) { <<-EOS }
            Foo::
              Bar:
              Baz:
          EOS

          it 'applies the rule' do
            subject[:exit_status].should == 0
          end
        end

        describe 'from the middle' do
          let(:start_state) { <<-EOS }
            Foo::
              Qux:
              Bar:
              Baz:
          EOS
          it_does_not_apply_the_rule
        end
      end

      describe 'that match out of order' do
        let(:start_state) { <<-EOS }
          Foo::
            Baz:
            Bar:
        EOS
        it_does_not_apply_the_rule
      end
    end
  end

  describe 'matching multiple nodes' do
    let(:rules) { <<-EOS }
      -Foo:
      -Bar:*
    EOS

    describe 'with no nodes that match' do
      let(:start_state) { "Foo:" }
      it_applies_the_rule ""
    end

    describe 'with one node that matches' do
      let(:start_state) { "Foo:\nBar:" }
      it_applies_the_rule ""
    end

    describe 'with multiple nodes that match' do
      let(:start_state) { "Foo:\nBar:\nBar:" }
      it_applies_the_rule ""
    end
  end

  describe 'not matching all nodes with a condition' do
    let(:rules) { <<-EOS }
      Foo:
        Bar:
        Baz:
      < exit(0);
    EOS

    describe 'with all child nodes matching' do
      let(:start_state) { <<-EOS }
        Foo:
          Bar:
          Baz:
      EOS

      it 'applies the rule' do
        subject[:exit_status].should == 0
      end
    end

    describe 'with some child nodes not matching' do
      let(:start_state) { <<-EOS }
        Foo:
          Bar:
          Baz:
          Qux:
      EOS

      it 'applies the rule' do
        subject[:exit_status].should == 0
      end
    end
  end

  describe 'matching all nodes with a condition' do
    let(:rules) { <<-EOS }
      Foo:=
        Bar:
        Baz:
      < exit(0);
    EOS

    describe 'with all child nodes matching' do
      let(:start_state) { <<-EOS }
        Foo:
          Bar:
          Baz:
      EOS

      it 'applies the rule' do
        subject[:exit_status].should == 0
      end
    end

    describe 'with some child nodes not matching' do
      let(:start_state) { <<-EOS }
        Foo:
          Bar:
          Baz:
          Qux:
      EOS
      it_does_not_apply_the_rule
    end
  end

  describe 'node values' do
    # TODO
  end

  describe 'variables' do
    describe 'referenced in a matching condition' do
      let(:rules) { <<-EOS }
        Matching: X
        !Matched:
        +Matched:
      EOS

      describe 'used in a code segment' do
        let(:rules) { <<-EOS }
          Matching: X
          !Matched:
          +Matched:
          < #{target}->value_type = integer;
          < #{target}->integer_value = 5;
        EOS
        let(:target) { '$X' }

        describe 'matching a leaf node' do
          let(:start_state) { "Matching:" }
          it_applies_the_rule "Matching: 5\nMatched:"
        end

        describe 'matching a node with children' do
          let(:start_state) { "Matching:\n  Child:" }
          let(:target) { '$X->children' }
          it_applies_the_rule "Matching:\n  Child: 5\nMatched:"
        end

        describe 'matching a node with a value' do
          let(:start_state) { "Matching: 4" }
          it_applies_the_rule "Matching: 5\nMatched:"
        end
      end

      describe 'matching a leaf node' do
        let(:start_state) { "Matching:" }
        it_applies_the_rule "Matching:\nMatched:"
      end

      describe 'matching a node with children' do
        let(:start_state) { "Matching:\n  Child:" }
        it_applies_the_rule "Matching:\n  Child:\nMatched:"
      end

      describe 'matching a node with a value' do
        let(:start_state) { "Matching: 4" }
        it_applies_the_rule "Matching: 4\nMatched:"
      end

      describe 'and another matching condition' do
        let(:rules) { <<-EOS }
          Matching 1: X
          Matching 2: X
          !Matched:
          +Matched:
        EOS

        describe 'used in a code segment' do
          let(:rules) { <<-EOS }
            Matching 1: X
            Matching 2: X
            !Matched:
            +Matched:
            < $X->value_type = none;
          EOS
          let(:start_state) { "Unmatched:" }

          it_causes_a_compile_error
        end

        describe 'matching a leaf node' do
          describe 'and a leaf node' do
            let(:start_state) { "Matching 1:\nMatching 2:" }
            it_applies_the_rule "Matching 1:\nMatching 2:\nMatched:"
          end

          describe 'and a node with children' do
            let(:start_state) { "Matching 1:\nMatching 2:\n  Child:" }
            it_does_not_apply_the_rule
          end

          describe 'and a node with a value' do
            let(:start_state) { "Matching 1:\nMatching 2: 5" }
            it_does_not_apply_the_rule
          end
        end

        describe 'matching a node with children' do
          describe 'and a node with children' do
            # TODO
          end

          describe 'and a node with a value' do
            let(:start_state) { "Matching 1:\n  Child:\nMatching 2: 5" }
            it_does_not_apply_the_rule
          end
        end

        describe 'matching a node with a value' do
          describe 'and a node with a value' do
            describe 'that are equal integers' do
              let(:start_state) { "Matching 1: 5\nMatching 2: 5" }
              it_applies_the_rule "Matching 1: 5\nMatching 2: 5\nMatched:"
            end

            describe 'that are unequal integers' do
              let(:start_state) { "Matching 1: 4\nMatching 2: 5" }
              it_does_not_apply_the_rule
            end

            describe 'that are equal decimals' do
              let(:start_state) { "Matching 1: 5.0\nMatching 2: 5.0" }
              it_applies_the_rule "Matching 1: 5.0\nMatching 2: 5.0\nMatched:"
            end

            describe 'that are unequal decimals' do
              let(:start_state) { "Matching 1: 4.0\nMatching 2: 5.0" }
              it_does_not_apply_the_rule
            end

            describe 'that are an integer and a decimal' do
              let(:start_state) { "Matching 1: 5\nMatching 2: 5.0" }
              it_does_not_apply_the_rule
            end
          end
        end

        describe 'and a removing condition' do
          let(:rules) { <<-EOS }
            Matching 1: X
            Matching 2: X
            -Removing: X
          EOS

          describe 'used in a code segment' do
            let(:rules) { <<-EOS }
              Matching 1: X
              Matching 2: X
              -Removing: X
              < $X->value_type = none;
            EOS
            let(:start_state) { "Unmatched:" }

            it_causes_a_compile_error
          end

          describe 'matching a leaf node' do
            describe 'and a leaf node' do
              describe 'and a leaf node' do
                let(:start_state) { "Matching 1:\nMatching 2:\nRemoving:" }
                it_applies_the_rule "Matching 1:\nMatching 2:"
              end

              describe 'and a node with children' do
                let(:start_state) { "Matching 1:\nMatching 2:\nRemoving:\n  Child:" }
                it_does_not_apply_the_rule
              end

              describe 'and a node with a value' do
                let(:start_state) { "Matching 1:\nMatching 2:\nRemoving: 5" }
                it_does_not_apply_the_rule
              end
            end

            describe 'and a node with children' do
              describe 'and a leaf node' do
                let(:start_state) { "Matching 1:\nMatching 2:\n  Child:\nRemoving:" }
                it_does_not_apply_the_rule
              end

              describe 'and a node with children' do
                let(:start_state) { "Matching 1:\nMatching 2:\n  Child:\nRemoving:\n  Child:" }
                it_does_not_apply_the_rule
              end

              describe 'and a node with a value' do
                let(:start_state) { "Matching 1:\nMatching 2:\n  Child:\nRemoving: 5" }
                it_does_not_apply_the_rule
              end
            end

            describe 'and a node with a value' do
              describe 'and a leaf node' do
                let(:start_state) { "Matching 1:\nMatching 2: 5\nRemoving:" }
                it_does_not_apply_the_rule
              end

              describe 'and a node with children' do
                let(:start_state) { "Matching 1:\nMatching 2: 5\nRemoving:\n  Child:" }
                it_does_not_apply_the_rule
              end

              describe 'and a node with a value' do
                let(:start_state) { "Matching 1:\nMatching 2: 5\nRemoving: 5" }
                it_does_not_apply_the_rule
              end
            end
          end

          describe 'matching a node with children' do
            describe 'and a node with children' do
              describe 'and a leaf node' do
                let(:start_state) { "Matching 1:\n  Child:\nMatching 2:\n  Child:\nRemoving:" }
                it_does_not_apply_the_rule
              end

              describe 'and a node with children' do
                # TODO
              end

              describe 'and a node with a value' do
                let(:start_state) { "Matching 1:\n  Child:\nMatching 2:\n  Child:\nRemoving: 5" }
                it_does_not_apply_the_rule
              end
            end

            describe 'and a node with a value' do
              describe 'and a leaf node' do
                let(:start_state) { "Matching 1:\n  Child:\nMatching 2: 5\nRemoving:" }
                it_does_not_apply_the_rule
              end

              describe 'and a node with children' do
                let(:start_state) { "Matching 1:\n  Child:\nMatching 2: 5\nRemoving:\n  Child:" }
                it_does_not_apply_the_rule
              end

              describe 'and a node with a value' do
                let(:start_state) { "Matching 1:\n  Child:\nMatching 2: 5\nRemoving: 5" }
                it_does_not_apply_the_rule
              end
            end
          end

          describe 'matching a node with a value' do
            describe 'and a node with a value' do
              describe 'and a leaf node' do
                let(:start_state) { "Matching 1: 5\nMatching 2: 5\nRemoving:" }
                it_does_not_apply_the_rule
              end

              describe 'and a node with children' do
                let(:start_state) { "Matching 1: 5\nMatching 2: 5\nRemoving:\n  Child:" }
                it_does_not_apply_the_rule
              end

              describe 'and a node with a value' do
                describe 'that are equal integers' do
                  let(:start_state) { "Matching 1: 5\nMatching 2: 5\nRemoving: 5" }
                  it_applies_the_rule "Matching 1: 5\nMatching 2: 5"
                end

                describe 'that are unequal integers' do
                  let(:start_state) { "Matching 1: 5\nMatching 2: 4\nRemoving: 5" }
                  it_does_not_apply_the_rule
                end

                describe 'that are equal decimals' do
                  let(:start_state) { "Matching 1: 5.3\nMatching 2: 5.3\nRemoving: 5.3" }
                  it_applies_the_rule "Matching 1: 5.3\nMatching 2: 5.3"
                end

                describe 'that are unequal decimals' do
                  let(:start_state) { "Matching 1: 5.3\nMatching 2: 4.3\nRemoving: 5.3" }
                  it_does_not_apply_the_rule
                end

                describe 'that are integers and decimals' do
                  let(:start_state) { "Matching 1: 5.0\nMatching 2: 5\nRemoving: 5.0" }
                  it_does_not_apply_the_rule
                end
              end
            end
          end

          describe 'and a creating condition' do
            let(:rules) { <<-EOS }
              Matching 1: X
              Matching 2: X
              -Removing: X
              +Creating: X
            EOS

            describe 'used in a code segment' do
              let(:rules) { <<-EOS }
                Matching 1: X
                Matching 2: X
                -Removing: X
                +Creating: X
                < $X->value_type = none;
              EOS
              let(:start_state) { "Unmatched:" }

              it_causes_a_compile_error
            end

            describe 'matching a leaf node' do
              describe 'and a leaf node' do
                describe 'and a leaf node' do
                  let(:start_state) { "Matching 1:\nMatching 2:\nRemoving:" }
                  it_applies_the_rule "Matching 1:\nMatching 2:\nCreating:"
                end

                describe 'and a node with children' do
                  let(:start_state) { "Matching 1:\nMatching 2:\nRemoving:\n  Child:" }
                  it_does_not_apply_the_rule
                end

                describe 'and a node with a value' do
                  let(:start_state) { "Matching 1:\nMatching 2:\nRemoving: 5" }
                  it_does_not_apply_the_rule
                end
              end

              describe 'and a node with children' do
                describe 'and a leaf node' do
                  let(:start_state) { "Matching 1:\nMatching 2:\n  Child:\nRemoving:" }
                  it_does_not_apply_the_rule
                end

                describe 'and a node with children' do
                  let(:start_state) { "Matching 1:\nMatching 2:\n  Child:\nRemoving:\n  Child:" }
                  it_does_not_apply_the_rule
                end

                describe 'and a node with a value' do
                  let(:start_state) { "Matching 1:\nMatching 2:\n  Child:\nRemoving: 5" }
                  it_does_not_apply_the_rule
                end
              end

              describe 'and a node with a value' do
                describe 'and a leaf node' do
                  let(:start_state) { "Matching 1:\nMatching 2: 5\nRemoving:" }
                  it_does_not_apply_the_rule
                end

                describe 'and a node with children' do
                  let(:start_state) { "Matching 1:\nMatching 2: 5\nRemoving:\n  Child:" }
                  it_does_not_apply_the_rule
                end

                describe 'and a node with a value' do
                  let(:start_state) { "Matching 1:\nMatching 2: 5\nRemoving: 5" }
                  it_does_not_apply_the_rule
                end
              end
            end

            describe 'matching a node with children' do
              describe 'and a node with children' do
                describe 'and a leaf node' do
                  let(:start_state) { "Matching 1:\n  Child:\nMatching 2:\n  Child:\nRemoving:" }
                  it_does_not_apply_the_rule
                end

                describe 'and a node with children' do
                  # TODO
                end

                describe 'and a node with a value' do
                  let(:start_state) { "Matching 1:\n  Child:\nMatching 2:\n  Child:\nRemoving: 5" }
                  it_does_not_apply_the_rule
                end
              end

              describe 'and a node with a value' do
                describe 'and a leaf node' do
                  let(:start_state) { "Matching 1:\n  Child:\nMatching 2: 5\nRemoving:" }
                  it_does_not_apply_the_rule
                end

                describe 'and a node with children' do
                  let(:start_state) { "Matching 1:\n  Child:\nMatching 2: 5\nRemoving:\n  Child:" }
                  it_does_not_apply_the_rule
                end

                describe 'and a node with a value' do
                  let(:start_state) { "Matching 1:\n  Child:\nMatching 2: 5\nRemoving: 5" }
                  it_does_not_apply_the_rule
                end
              end
            end

            describe 'matching a node with a value' do
              describe 'and a node with a value' do
                describe 'and a leaf node' do
                  let(:start_state) { "Matching 1: 5\nMatching 2: 5\nRemoving:" }
                  it_does_not_apply_the_rule
                end

                describe 'and a node with children' do
                  let(:start_state) { "Matching 1: 5\nMatching 2: 5\nRemoving:\n  Child:" }
                  it_does_not_apply_the_rule
                end

                describe 'and a node with a value' do
                  describe 'that are equal integers' do
                    let(:start_state) { "Matching 1: 5\nMatching 2: 5\nRemoving: 5" }
                    it_applies_the_rule "Matching 1: 5\nMatching 2: 5\nCreating:"
                  end

                  describe 'that are unequal integers' do
                    let(:start_state) { "Matching 1: 5\nMatching 2: 4\nRemoving: 5" }
                    it_does_not_apply_the_rule
                  end

                  describe 'that are equal decimals' do
                    let(:start_state) { "Matching 1: 5.3\nMatching 2: 5.3\nRemoving: 5.3" }
                    it_applies_the_rule "Matching 1: 5.3\nMatching 2: 5.3\nCreating:"
                  end

                  describe 'that are unequal decimals' do
                    let(:start_state) { "Matching 1: 5.3\nMatching 2: 4.3\nRemoving: 5.3" }
                    it_does_not_apply_the_rule
                  end

                  describe 'that are integers and decimals' do
                    let(:start_state) { "Matching 1: 5.0\nMatching 2: 5\nRemoving: 5.0" }
                    it_does_not_apply_the_rule
                  end
                end
              end
            end

            describe 'and a preventing condition' do
              let(:rules) { <<-EOS }
                Matching 1: X
                Matching 2: X
                -Removing: X
                +Creating: X
                !Preventing: X
              EOS

              describe 'used in a code segment' do
                let(:rules) { <<-EOS }
                  Matching 1: X
                  Matching 2: X
                  -Removing: X
                  +Creating: X
                  !Preventing: X
                  < $X->value_type = none;
                EOS
                let(:start_state) { "Unmatched:" }

                it_causes_a_compile_error
              end

              describe 'matching a leaf node' do
                describe 'and a leaf node' do
                  describe 'and a leaf node' do
                    describe 'and a leaf node' do
                      let(:start_state) { "Matching 1:\nMatching 2:\nRemoving:\nPreventing:" }
                      it_does_not_apply_the_rule
                    end

                    describe 'and a node with children' do
                      let(:start_state) { "Matching 1:\nMatching 2:\nRemoving:\nPreventing:\n  Child:" }
                      it_applies_the_rule "Matching 1:\nMatching 2:\nPreventing:\n  Child:"
                    end

                    describe 'and a node with a value' do
                      let(:start_state) { "Matching 1:\nMatching 2:\nRemoving:\nPreventing: 5" }
                      it_applies_the_rule "Matching 1:\nMatching 2:\nPreventing: 5"
                    end
                  end

                  describe 'and a node with children' do
                    describe 'and a leaf node' do
                      let(:start_state) { "Matching 1:\nMatching 2:\nRemoving:\n  Child:\nPreventing:" }
                      it_does_not_apply_the_rule
                    end

                    describe 'and a node with children' do
                      let(:start_state) { "Matching 1:\nMatching 2:\nRemoving:\n  Child:\nPreventing:\n  Child:" }
                      it_does_not_apply_the_rule
                    end

                    describe 'and a node with a value' do
                      let(:start_state) { "Matching 1:\nMatching 2:\nRemoving:\n  Child:\nPreventing: 5" }
                      it_does_not_apply_the_rule
                    end
                  end

                  describe 'and a node with a value' do
                    describe 'and a leaf node' do
                      let(:start_state) { "Matching 1:\nMatching 2:\nRemoving: 5\nPreventing:" }
                      it_does_not_apply_the_rule
                    end

                    describe 'and a node with children' do
                      let(:start_state) { "Matching 1:\nMatching 2:\nRemoving: 5\nPreventing:\n  Child:" }
                      it_does_not_apply_the_rule
                    end

                    describe 'and a node with a value' do
                      let(:start_state) { "Matching 1:\nMatching 2:\nRemoving: 5\nPreventing: 5" }
                      it_does_not_apply_the_rule
                    end
                  end
                end

                describe 'and a node with children' do
                  describe 'and a leaf node' do
                    describe 'and a leaf node' do
                      let(:start_state) { "Matching 1:\nMatching 2:\n  Child:\nRemoving:\nPreventing:" }
                      it_does_not_apply_the_rule
                    end

                    describe 'and a node with children' do
                      let(:start_state) { "Matching 1:\nMatching 2:\n  Child:\nRemoving:\nPreventing:\n  Child:" }
                      it_does_not_apply_the_rule
                    end

                    describe 'and a node with a value' do
                      let(:start_state) { "Matching 1:\nMatching 2:\n  Child:\nRemoving:\nPreventing: 5" }
                      it_does_not_apply_the_rule
                    end
                  end

                  describe 'and a node with children' do
                    describe 'and a leaf node' do
                      let(:start_state) { "Matching 1:\nMatching 2:\n  Child:\nRemoving:\n  Child:\nPreventing:" }
                      it_does_not_apply_the_rule
                    end

                    describe 'and a node with children' do
                      let(:start_state) { "Matching 1:\nMatching 2:\n  Child:\nRemoving:\n  Child:\nPreventing:\n  Child:" }
                      it_does_not_apply_the_rule
                    end

                    describe 'and a node with a value' do
                      let(:start_state) { "Matching 1:\nMatching 2:\n  Child:\nRemoving:\n  Child:\nPreventing: 5" }
                      it_does_not_apply_the_rule
                    end
                  end

                  describe 'and a node with a value' do
                    describe 'and a leaf node' do
                      let(:start_state) { "Matching 1:\nMatching 2:\n  Child:\nRemoving: 5\nPreventing:" }
                      it_does_not_apply_the_rule
                    end

                    describe 'and a node with children' do
                      let(:start_state) { "Matching 1:\nMatching 2:\n  Child:\nRemoving: 5\nPreventing:\n  Child:" }
                      it_does_not_apply_the_rule
                    end

                    describe 'and a node with a value' do
                      let(:start_state) { "Matching 1:\nMatching 2:\n  Child:\nRemoving: 5\nPreventing: 5" }
                      it_does_not_apply_the_rule
                    end
                  end
                end

                describe 'and a node with a value' do
                  describe 'and a leaf node' do
                    describe 'and a leaf node' do
                      let(:start_state) { "Matching 1:\nMatching 2: 5\nRemoving:\nPreventing:" }
                      it_does_not_apply_the_rule
                    end

                    describe 'and a node with children' do
                      let(:start_state) { "Matching 1:\nMatching 2: 5\nRemoving:\nPreventing:\n  Child:" }
                      it_does_not_apply_the_rule
                    end

                    describe 'and a node with a value' do
                      let(:start_state) { "Matching 1:\nMatching 2: 5\nRemoving:\nPreventing: 5" }
                      it_does_not_apply_the_rule
                    end
                  end

                  describe 'and a node with children' do
                    describe 'and a leaf node' do
                      let(:start_state) { "Matching 1:\nMatching 2: 5\nRemoving:\n  Child:\nPreventing:" }
                      it_does_not_apply_the_rule
                    end

                    describe 'and a node with children' do
                      let(:start_state) { "Matching 1:\nMatching 2: 5\nRemoving:\n  Child:\nPreventing:\n  Child:" }
                      it_does_not_apply_the_rule
                    end

                    describe 'and a node with a value' do
                      let(:start_state) { "Matching 1:\nMatching 2: 5\nRemoving:\n  Child:\nPreventing: 5" }
                      it_does_not_apply_the_rule
                    end
                  end

                  describe 'and a node with a value' do
                    describe 'and a leaf node' do
                      let(:start_state) { "Matching 1:\nMatching 2: 5\nRemoving: 5\nPreventing:" }
                      it_does_not_apply_the_rule
                    end

                    describe 'and a node with children' do
                      let(:start_state) { "Matching 1:\nMatching 2: 5\nRemoving: 5\nPreventing:\n  Child:" }
                      it_does_not_apply_the_rule
                    end

                    describe 'and a node with a value' do
                      let(:start_state) { "Matching 1:\nMatching 2: 5\nRemoving: 5\nPreventing: 5" }
                      it_does_not_apply_the_rule
                    end
                  end
                end
              end

              describe 'matching a node with children' do
                describe 'and a node with children' do
                  describe 'and a leaf node' do
                    describe 'and a leaf node' do
                      let(:start_state) { "Matching 1:\n  Child:\nMatching 2:\n  Child:\nRemoving:\nPreventing:" }
                      it_does_not_apply_the_rule
                    end

                    describe 'and a node with children' do
                      let(:start_state) { "Matching 1:\n  Child:\nMatching 2:\n  Child:\nRemoving:\nPreventing:\n  Child:" }
                      it_does_not_apply_the_rule
                    end

                    describe 'and a node with a value' do
                      let(:start_state) { "Matching 1:\n  Child:\nMatching 2:\n  Child:\nRemoving:\nPreventing: 5" }
                      it_does_not_apply_the_rule
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
                      let(:start_state) { "Matching 1:\n  Child:\nMatching 2:\n  Child:\nRemoving: 5\nPreventing:" }
                      it_does_not_apply_the_rule
                    end

                    describe 'and a node with children' do
                      let(:start_state) { "Matching 1:\n  Child:\nMatching 2:\n  Child:\nRemoving: 5\nPreventing:\n  Child:" }
                      it_does_not_apply_the_rule
                    end

                    describe 'and a node with a value' do
                      let(:start_state) { "Matching 1:\n  Child:\nMatching 2:\n  Child:\nRemoving: 5\nPreventing: 5" }
                      it_does_not_apply_the_rule
                    end
                  end
                end

                describe 'and a node with a value' do
                  describe 'and a leaf node' do
                    describe 'and a leaf node' do
                      let(:start_state) { "Matching 1:\n  Child:\nMatching 2: 5\nRemoving:\nPreventing:" }
                      it_does_not_apply_the_rule
                    end

                    describe 'and a node with children' do
                      let(:start_state) { "Matching 1:\n  Child:\nMatching 2: 5\nRemoving:\nPreventing:\n  Child:" }
                      it_does_not_apply_the_rule
                    end

                    describe 'and a node with a value' do
                      let(:start_state) { "Matching 1:\n  Child:\nMatching 2: 5\nRemoving:\nPreventing: 5" }
                      it_does_not_apply_the_rule
                    end
                  end

                  describe 'and a node with children' do
                    describe 'and a leaf node' do
                      let(:start_state) { "Matching 1:\n  Child:\nMatching 2: 5\nRemoving:\n  Child:\nPreventing:" }
                      it_does_not_apply_the_rule
                    end

                    describe 'and a node with children' do
                      let(:start_state) { "Matching 1:\n  Child:\nMatching 2: 5\nRemoving:\n  Child:\nPreventing:\n  Child:" }
                      it_does_not_apply_the_rule
                    end

                    describe 'and a node with a value' do
                      let(:start_state) { "Matching 1:\n  Child:\nMatching 2: 5\nRemoving:\n  Child:\nPreventing: 5" }
                      it_does_not_apply_the_rule
                    end
                  end

                  describe 'and a node with a value' do
                    describe 'and a leaf node' do
                      let(:start_state) { "Matching 1:\n  Child:\nMatching 2: 5\nRemoving: 5\nPreventing:" }
                      it_does_not_apply_the_rule
                    end

                    describe 'and a node with children' do
                      let(:start_state) { "Matching 1:\n  Child:\nMatching 2: 5\nRemoving: 5\nPreventing:\n  Child:" }
                      it_does_not_apply_the_rule
                    end

                    describe 'and a node with a value' do
                      let(:start_state) { "Matching 1:\n  Child:\nMatching 2: 5\nRemoving: 5\nPreventing: 5" }
                      it_does_not_apply_the_rule
                    end
                  end
                end
              end

              describe 'matching a node with a value' do
                describe 'and a node with a value' do
                  describe 'and a leaf node' do
                    describe 'and a leaf node' do
                      let(:start_state) { "Matching 1: 5\nMatching 2: 5\nRemoving:\nPreventing:" }
                      it_does_not_apply_the_rule
                    end

                    describe 'and a node with children' do
                      let(:start_state) { "Matching 1: 5\nMatching 2: 5\nRemoving:\nPreventing:\n  Child:" }
                      it_does_not_apply_the_rule
                    end

                    describe 'and a node with a value' do
                      let(:start_state) { "Matching 1: 5\nMatching 2: 5\nRemoving:\nPreventing: 5" }
                      it_does_not_apply_the_rule
                    end
                  end

                  describe 'and a node with children' do
                    describe 'and a leaf node' do
                      let(:start_state) { "Matching 1: 5\nMatching 2: 5\nRemoving:\n  Child:\nPreventing:" }
                      it_does_not_apply_the_rule
                    end

                    describe 'and a node with children' do
                      let(:start_state) { "Matching 1: 5\nMatching 2: 5\nRemoving:\n  Child:\nPreventing:\n  Child:" }
                      it_does_not_apply_the_rule
                    end

                    describe 'and a node with a value' do
                      let(:start_state) { "Matching 1: 5\nMatching 2: 5\nRemoving:\n  Child:\nPreventing: 5" }
                      it_does_not_apply_the_rule
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
