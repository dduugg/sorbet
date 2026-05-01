# typed: false
# A top-level def call(**opts) with no sig lands on Object (root methods go on
# Object via methodOwner). Object#call(**opts) then has param.type==nullptr for
# the kwrestarg, which triggers the bug when getCallArguments("call") is called
# on NilClass during block type inference in test2.rb.
def call(**opts); end
