class DropCallToActionTable < ActiveRecord::Migration[6.1]
  def up
  end
  
  def down
    fail ActiveRecord::IrreversibleMigration
  end
end
