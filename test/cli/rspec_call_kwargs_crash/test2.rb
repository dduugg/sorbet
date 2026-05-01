# typed: true
extend T::Sig

class PayrollTax; end

class PayrollTaxCollection
  extend T::Sig
  # Mirrors ActiveRecord DSL-generated any? sig:
  #   T.nilable(T.proc.params(record: Elem)) creates OrType(T.proc, NilClass) as blockPreType.
  # NilClass now inherits Object#call(**opts) from test.rb.
  # NilClass.getCallArguments("call") -> getMethodParametersAsTuple -> **opts with
  # param.type==nullptr -> isRepeated branch -> Types::arrayOf(nullptr)
  # -> AppliedType(Array,[nullptr]) -> Types::glb(TupleType([PayrollTax]), Array<nullptr>)
  # -> isSubTypeUnderConstraint crash.
  sig { params(block: T.nilable(T.proc.params(record: PayrollTax).returns(T.untyped))).returns(T::Boolean) }
  def any?(&block); end
end

class Payroll
  extend T::Sig

  sig { returns(PayrollTaxCollection) }
  def payroll_taxes; T.unsafe(nil); end

  sig { returns(T::Boolean) }
  def is_precision_dated?
    payroll_taxes.any? { |pt| pt.nil? }
  end
end
