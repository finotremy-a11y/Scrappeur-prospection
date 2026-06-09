class CreateOrganizations < ActiveRecord::Migration[8.1]
  def change
    create_table :organizations do |t|
      t.string :name
      t.string :email
      t.integer :category
      t.string :source
      t.string :city
      t.string :department

      t.timestamps
    end
  end
end
