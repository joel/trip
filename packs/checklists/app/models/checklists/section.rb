# frozen_string_literal: true

module Checklists
  class Section < ApplicationRecord
    self.table_name = "checklist_sections"

    def self.model_name
      ActiveModel::Name.new(self, nil, "ChecklistSection")
    end

    belongs_to :checklist, class_name: "Checklists::Checklist"

    has_many :checklist_items, -> { order(position: :asc) },
             class_name: "Checklists::Item",
             inverse_of: :checklist_section, dependent: :destroy

    validates :name, presence: true
  end
end
