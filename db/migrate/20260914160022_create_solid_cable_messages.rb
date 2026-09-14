# frozen_string_literal: true

# Action Cable's pubsub table. Lives in the primary database rather than a
# separate `cable` one: this app runs a single database per environment, and
# solid_cable falls back to ActiveRecord::Base's connection when cable.yml
# names no `connects_to`. Mirrors the schema solid_cable ships in
# db/cable_schema.rb, with the limits Postgres actually honours.
class CreateSolidCableMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :solid_cable_messages do |t|
      t.binary :channel, null: false
      t.binary :payload, null: false
      t.datetime :created_at, null: false
      t.bigint :channel_hash, null: false

      t.index :channel
      t.index :channel_hash
      t.index :created_at
    end
  end
end
