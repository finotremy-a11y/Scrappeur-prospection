require "test_helper"

class OrganizationsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get root_url
    assert_response :success
  end

  test "prospecting scan stores analysis and redirects to sorted results" do
    organization = Organization.create!(
      name: "Prospect Lyon", city: "Lyon", category: :b2b,
      website: "https://example.com"
    )
    Organization.create!(name: "Sans site", city: "Lyon", category: :b2b, website: nil)
    Organization.create!(name: "Domaine invalide", city: "Lyon", category: :b2b, website: "https://localhost")

    stub_analysis do
      post prospecting_scan_path, params: { city: "Lyon", category: "b2b" }
    end

    assert_redirected_to prospecting_results_path
    follow_redirect!
    assert_select ".alert-notice", text: /1 entreprise ignorée\(s\) faute de site web/
    refute_includes response.body, "Sans site"
    refute_includes response.body, "Domaine invalide"
    assert_select "h1", /Lyon/
    assert_includes response.body, organization.name
  end

  test "prospecting export contains only the ten hottest prospects" do
    11.times do |index|
      Organization.create!(
        name: "Prospect #{index}", city: "Paris", category: :restaurant,
        lead_score: index, website: "https://example.com/#{index}"
      )
    end

    open_session do |session|
      stub_analysis { session.post prospecting_scan_path, params: { city: "Paris", category: "restaurant" } }
      Organization.where(city: "Paris").order(name: :asc).each_with_index { |organization, index| organization.update!(lead_score: index) }
      session.get prospecting_export_path
      assert_equal "text/csv", session.response.media_type
      assert_equal 11, session.response.body.lines.size
      assert_includes session.response.body.lines[1], "Prospect 9"
      refute_includes session.response.body, "Prospect 0"
    end
  end

  private

  def stub_analysis(&block)
    result = WebsiteAnalyzer::Result.new(http_status: 200, load_time_sec: 1.0, is_https: true, has_form: true, has_conversion_keywords: false)
    original = WebsiteAnalyzer.instance_method(:analyze)
    WebsiteAnalyzer.send(:define_method, :analyze) { result }
    block.call
  ensure
    WebsiteAnalyzer.send(:define_method, :analyze, original)
  end
end
