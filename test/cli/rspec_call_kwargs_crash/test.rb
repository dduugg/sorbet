# typed: false
# frozen_string_literal: true
# This file reproduces the crash. A top-level def call(**opts) lands on Object
# (root-level defs go on Object via methodOwner). Object#call(**opts) has no sig,
# so param.type==nullptr for the kwrestarg. When a typed:true method yields
# through a nilable-proc block type, OrType::getCallArguments("call") finds
# Object#call via NilClass inheritance, producing AppliedType(Array,[nullptr])
# which propagates through Types::glb -> isSubTypeUnderConstraint -> crash.

def call(**opts); end
