# typed: true
# enable-experimental-rspec: true

module RSpec
  module Core
    class ExampleGroup
    end
  end
end

# Regression: the Minitest rewriter must handle `def call(**kwargs)` inside a
# nested RSpec describe block without crashing. With --enable-experimental-rspec,
# the outer RSpec.describe is rewritten to a ClassDef and def call(**opts) lands
# on the synthesized inner class (not Object), so the inference-level null-ptr
# crash is not triggered here. That crash — where Object#call(**opts) causes
# NilClass.getCallArguments to produce AppliedType(Array,[nullptr]) — is covered
# by test/cli/rspec_call_kwargs_crash/.
RSpec.describe "something" do
  describe ".method" do
    def call(**opts)
      opts[:key]
    end

    it "works" do
      call(key: 1)
    end
  end
end
