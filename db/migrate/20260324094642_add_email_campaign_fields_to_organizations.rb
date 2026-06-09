class AddEmailCampaignFieldsToOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :email_sent_at, :datetime
    add_column :organizations, :unsubscribed_at, :datetime
  end
end
