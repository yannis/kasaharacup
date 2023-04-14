# frozen_string_literal: true

class CreateWebhooks < ActiveRecord::Migration[7.0]
  def change
    create_table :webhooks do |t|
      t.string :stripe_id
      t.string :event_type
      t.json :payload

      t.timestamps
    end
  end
end
