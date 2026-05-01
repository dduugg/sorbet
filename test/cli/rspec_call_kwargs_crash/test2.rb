# typed: true
extend T::Sig

class PayrollTax; end

class PayrollTaxCollection
  extend T::Sig
  # Mirrors ActiveRecord DSL-generated any? sig (sorbet/rbi/dsl/*.rbi).
  # The nilable proc block type creates blockPreType = OrType(T.proc.params(PayrollTax), NilClass).
  # OrType::getCallArguments("call") is then called during block type inference.
  # NilClass inherits Object#call(**opts) from test.rb, which has param.type==nullptr.
  # This causes getMethodParametersAsTuple to produce AppliedType(Array,[nullptr]),
  # which propagates to isSubTypeUnderConstraintSingle and crashes.
  sig { params(block: T.nilable(T.proc.params(record: PayrollTax).returns(T.untyped))).returns(T::Boolean) }
  def any?(&block); T.unsafe(nil); end
end

class Payroll
  extend T::Sig

  sig { returns(PayrollTaxCollection) }
  def payroll_taxes; T.unsafe(nil); end

  sig { returns(T::Boolean) }
  def check
    payroll_taxes.any? { |pt| pt.nil? }
  end
end
