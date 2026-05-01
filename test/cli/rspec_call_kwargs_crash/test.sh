#!/bin/bash

set -euo pipefail

# test2.rb alone: should always succeed (no crash, no errors)
echo "--- test2.rb alone ---"
main/sorbet --max-threads=0 --censor-for-snapshot-tests --silence-dev-message \
  test/cli/rspec_call_kwargs_crash/test2.rb 2>&1

echo "--- test.rb + test2.rb ---"
# Regression: before the fix, def call(**opts) at the top level (test.rb) registers
# Object#call with param.type==nullptr. This caused OrType::getCallArguments to call
# getMethodParametersAsTuple for NilClass (which inherits Object#call), producing
# AppliedType(Array,[nullptr]) and crashing isSubTypeUnderConstraint in test2.rb.
main/sorbet --max-threads=0 --censor-for-snapshot-tests --silence-dev-message \
  test/cli/rspec_call_kwargs_crash/test.rb \
  test/cli/rspec_call_kwargs_crash/test2.rb 2>&1
