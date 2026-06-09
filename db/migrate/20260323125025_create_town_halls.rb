class CreateTownHalls < ActiveRecord::Migration[8.1]
  def change
    create_table :town_halls do |t|
      t.string :name
      t.string :email
      t.string :department

      t.timestamps
    end
  end
end
