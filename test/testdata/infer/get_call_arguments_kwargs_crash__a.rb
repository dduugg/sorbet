# typed: false
# File A: def call(**opts) at the top level registers Object#call with
# param.type==nullptr (no sig). This is the trigger. Combine with __b to crash.
def call(**opts); end
