# frozen_string_literal: true
# typed: true

module T::Private::Final
  def self.declare(mod)
    if !mod.is_a?(Class)
      raise "#{mod.name} is not a class or method and cannot be declared as final"
    end
    if final_class?(mod)
      raise "#{mod.name} was already declared as final and cannot be re-declared as final"
    end
    if T::AbstractUtils.abstract_module?(mod)
      raise "#{mod.name} was already declared as abstract and cannot be declared as final"
    end
    T::Private::ClassUtils.replace_method(mod.singleton_class, :inherited) do |subclass|
      super(subclass)
      raise "#{mod.name} was declared as final and cannot be inherited from"
    end
    mark_as_final_class(mod)
  end

  def self.final_class?(mod)
    !!mod.instance_variable_get(:@sorbet_final_class) # rubocop:disable PrisonGuard/NoLurkyInstanceVariableAccess
  end

  private_class_method def self.mark_as_final_class(mod)
    mod.instance_variable_set(:@sorbet_final_class, true) # rubocop:disable PrisonGuard/NoLurkyInstanceVariableAccess
  end
end
