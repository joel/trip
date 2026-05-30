# frozen_string_literal: true

module Checklists
  class Item < ApplicationRecord
    self.table_name = "checklist_items"

    def self.model_name
      ActiveModel::Name.new(self, nil, "ChecklistItem")
    end

    belongs_to :checklist_section, class_name: "Checklists::Section"

    validates :content, presence: true

    scope :ordered, -> { order(position: :asc, created_at: :asc) }

    def toggle!
      update!(completed: !completed)
    end
  end
end
