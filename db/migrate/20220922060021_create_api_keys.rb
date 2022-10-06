class CreateApiKeys < ActiveRecord::Migration[6.1]
  def change
    create_table :api_keys do |t|
      t.string :slug, null: false, unique: true
      t.string :label, null: false, default: 'customer_identifier_here'
      t.string :authentication_strategy, null: false, default: 'bearer_token'
      t.string :bearer_token, unique: true

      t.timestamps
    end
    add_index :api_keys, :bearer_token
  end
end
