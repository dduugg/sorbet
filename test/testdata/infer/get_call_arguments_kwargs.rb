# typed: true
extend T::Sig

class CallTakesKwargs
  def call(**opts)
    p opts
  end
end

sig {params(blk: CallTakesKwargs).void}
#           ^^^ error: Block argument type must be either `Proc` or a `T.proc` type (and possibly nilable)
def example(&blk)
  yield 42
end

example do |x|
  T.reveal_type(x) # error: `T.untyped`
end
