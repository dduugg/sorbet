# typed: false

# Regression test: defining `def call(**kwargs)` inside an RSpec describe block
# used to cause a segfault. The method ends up on a synthesized ClassDef from
# the Minitest rewriter, and getMethodParametersAsTuple produced AppliedType(Array,[nullptr])
# for the kwrestarg when param.type==nullptr, which propagated to a null dereference.

RSpec.describe "something" do
  describe "inner" do
    def call(**opts)
      opts[:key]
    end

    it "works" do
      call(key: 1)
    end
  end
end
