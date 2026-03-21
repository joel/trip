# frozen_string_literal: true

class BaseAction
  include Dry::Monads[:result, :do]
end
