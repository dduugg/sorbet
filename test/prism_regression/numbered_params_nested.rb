# typed: false

# Test that numbered parameters in nested blocks each have their own scope
# Similar to it_param_nested.rb

# Outer uses _1, inner uses explicit param - allowed
tap { _1.tap { |x| x } }

# Outer uses explicit param, inner uses _1 - allowed
tap { |x| x.tap { _1 } }

# Both outer and inner use _1 - not allowed in Ruby
# Unlike 'it', Ruby doesn't allow nested blocks to both use numbered parameters
[[1, 2], [3, 4]].map { _1.map { _1 * 2 } }
#                                ^^ error: numbered parameter is already used in outer block

