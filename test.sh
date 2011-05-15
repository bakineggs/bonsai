#!/bin/bash

cd tests

for name in `ls`; do
  ./../interpreter $name/rules.okk $name/start_state.okks > $name/actual_end_state.okks
  error_status=$?

  diff $name/end_state.okks $name/actual_end_state.okks > /dev/null
  different=$?

  if [ $error_status -o $different ]; then
    echo "Test $name failed with the following errors:"

    if [ $error_status ]; then
      echo "  Interpreter returned non-zero status ($error_status)"
    fi

    if [ $different ]; then
      echo "  End state was different than expected"
    fi

    echo
  fi
done
