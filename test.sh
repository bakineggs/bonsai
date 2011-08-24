#!/bin/bash

cd tests

leaf_directories=`find . -type d | sort | awk '$0 !~ last {print last} {last=$0} END {print last}'` # http://stackoverflow.com/questions/1574403/list-all-leaf-subdirectories-in-linux
for name in $leaf_directories; do
  ./../interpreter $name/rules.okk $name/start_state.okks > $name/actual_end_state.okks 2> $name/error.log
  error_status=$?

  ./../state_diff $name/end_state.okks $name/actual_end_state.okks
  different=$?

  if [ $error_status != 0 -o $different != 0 ]; then
    echo "Test $name failed with the following errors:"

    if [ $error_status != 0 ]; then
      echo "  Interpreter returned non-zero status ($error_status)"
    fi

    if [ $different != 0 ]; then
      echo "  End state was different than expected"
    fi

    echo
  fi
done
