# frozen_string_literal: true

class CreateAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_logs, id: :uuid do |t|
      t.references :trip, type: :uuid, null: true, foreign_key: false
      t.references :actor, type: :uuid, null: true,
                           foreign_key: { to_table: :users }
      t.string :actor_label, null: false
      t.string :action, null: false
      t.string :auditable_type
      t.uuid :auditable_id
      t.string :summary, null: false
      t.json :metadata, null: false, default: {}
      t.integer :source, null: false, default: 0
      t.string :request_id
      t.string :event_uid, null: false
      t.datetime :occurred_at, null: false
      t.timestamps
    end

    add_index :audit_logs, %i[trip_id occurred_at id],
              name: "idx_audit_logs_trip_feed"
    add_index :audit_logs, %i[occurred_at id],
              name: "idx_audit_logs_global_feed"
    add_index :audit_logs, %i[auditable_type auditable_id],
              name: "idx_audit_logs_target"
    add_index :audit_logs, :request_id, name: "idx_audit_logs_request"
    add_index :audit_logs, :event_uid, unique: true,
                                       name: "idx_audit_logs_event_uid"
  end
end
