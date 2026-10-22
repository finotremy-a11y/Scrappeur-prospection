class AddWebsiteAnalysisToOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :website, :string unless column_exists?(:organizations, :website)
    add_column :organizations, :http_status, :integer unless column_exists?(:organizations, :http_status)
    add_column :organizations, :load_time_sec, :decimal, precision: 8, scale: 3 unless column_exists?(:organizations, :load_time_sec)
    add_column :organizations, :is_https, :boolean unless column_exists?(:organizations, :is_https)
    add_column :organizations, :cms_detected, :string unless column_exists?(:organizations, :cms_detected)
    add_column :organizations, :has_form, :boolean unless column_exists?(:organizations, :has_form)
    add_column :organizations, :has_conversion_keywords, :boolean unless column_exists?(:organizations, :has_conversion_keywords)
    add_column :organizations, :lead_score, :integer unless column_exists?(:organizations, :lead_score)
  end
end
