require "test_helper"
require "capybara/rails"
require "capybara/minitest"

class ProspectingDashboardTest < ActionDispatch::IntegrationTest
  include Capybara::DSL
  include Capybara::Minitest::Assertions

  setup { Capybara.current_driver = :rack_test }
  teardown { Capybara.use_default_driver }

  test "scan lists only valid URLs and shows no invalid URL alert" do
    Organization.create!(name: "Avec site", city: "Nice", category: :restaurant, website: "https://example.com")
    Organization.create!(name: "Sans site", city: "Nice", category: :restaurant, website: nil)
    Organization.create!(name: "Domaine bidon", city: "Nice", category: :restaurant, website: "https://localhost")

    original = WebsiteAnalyzer.instance_method(:analyze)
    result = WebsiteAnalyzer::Result.new(http_status: 200, load_time_sec: 1.0, is_https: true, has_form: true, has_conversion_keywords: false)
    WebsiteAnalyzer.send(:define_method, :analyze) { result }

    visit prospecting_path
    fill_in "city", with: "Nice"
    select "Restaurant", from: "category"
    click_button "Lancer le Scan"

    assert_current_path prospecting_results_path
    assert_text "Avec site"
    assert_no_text "Sans site"
    assert_no_text "Domaine bidon"
    assert_no_text "URL invalide"
    assert_no_css ".alert-notice"
  ensure
    WebsiteAnalyzer.send(:define_method, :analyze, original) if original
  end
end
