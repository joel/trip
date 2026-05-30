# frozen_string_literal: true

module Checklists
  class Checklist < ApplicationRecord
    self.table_name = "checklists"

    # Preserve the un-namespaced route/param keys (checklist, checklists) so
    # existing routes, form_with, and polymorphic_path keep working after the
    # move into the Checklists:: namespace.
    def self.model_name
      ActiveModel::Name.new(self, nil, "Checklist")
    end

    belongs_to :trip

    has_many :checklist_sections, -> { order(position: :asc) },
             class_name: "Checklists::Section",
             inverse_of: :checklist, dependent: :destroy

    validates :name, presence: true

    scope :ordered, -> { order(position: :asc, created_at: :asc) }
  end
end
