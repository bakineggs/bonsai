#!/bin/bash

cd ../tests

leaf_directories=`find . -type d | sort | awk '$0 !~ last {print last} {last=$0} END {print last}'` # http://stackoverflow.com/questions/1574403/list-all-leaf-subdirectories-in-linux
for name in $leaf_directories; do
  ./../bootstrapped/parser $name/rules.okk $name/start_state.okks > $name/bootstrapped_start_state.okks 2> $name/parser_error.log
  parser_status=$?

  if [ $parser_status != 0 ]; then
    echo "Test $name failed with the following errors:"
    echo "  Parser returned non-zero status ($parser_status)"
    echo
  else
    ./../interpreter ../bootstrapped/rules.okk $name/bootstrapped_start_state.okks > $name/actual_end_state.okks 2> $name/interpreter_error.log
    interpreter_status=$?

    diff $name/end_state.okks $name/actual_end_state.okks > /dev/null 2> /dev/null
    different=$?

    if [ $interpreter_status != 0 -o $different != 0 ]; then
      echo "Test $name failed with the following errors:"

      if [ $interpreter_status != 0 ]; then
        echo "  Interpreter returned non-zero status ($interpreter_status)"
      fi

      if [ $different != 0 ]; then
        echo "  End state was different than expected"
      fi

      echo
    fi
  fi
done
