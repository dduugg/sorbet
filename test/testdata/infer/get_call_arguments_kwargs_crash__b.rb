# typed: true
extend T::Sig

class Elem; end

class Collection
  extend T::Sig
  # T.nilable(T.proc.params(record: Elem)) creates blockPreType =
  # OrType(T.proc.params(Elem).returns(T.untyped), NilClass).
  # OrType::getCallArguments("call") then hits NilClass, which inherits
  # Object#call(**opts) from __a.rb. getMethodParametersAsTuple returns
  # AppliedType(Array,[nullptr]), which crashes isSubTypeUnderConstraintSingle.
  sig { params(block: T.nilable(T.proc.params(record: Elem).returns(T.untyped))).returns(T::Boolean) }
  def any?(&block); T.unsafe(nil); end
end

class Caller
  extend T::Sig
  sig { returns(Collection) }
  def items; T.unsafe(nil); end
  sig { returns(T::Boolean) }
  def check
    items.any? { |e| e.nil? }
  end
end
