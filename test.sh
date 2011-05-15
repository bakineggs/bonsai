#!/bin/bash

cd tests

for name in `ls`; do
  ./../interpreter $name/rules.okk $name/start_state.okks > $name/actual_end_state.okks
  error_status=$?

  diff $name/end_state.okks $name/actual_end_state.okks
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
