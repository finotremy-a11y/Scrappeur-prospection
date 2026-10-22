require "test_helper"

class OrganizationTest < ActiveSupport::TestCase
  test "in_city ignores case, accents, hyphens and apostrophes" do
    Organization.create!(name: "A", category: :b2b, city: "Pont De Salars", website: "https://a.test")
    Organization.create!(name: "B", category: :b2b, city: "Sète", website: nil)
    Organization.create!(name: "C", category: :b2b, city: "L'Isle-Adam", website: "")

    assert_includes Organization.in_city("Pont-de-Salars").pluck(:name), "A"
    assert_includes Organization.in_city("pont de salars").pluck(:name), "A"
    assert_equal [ "B" ], Organization.in_city("sete").pluck(:name)
    assert_equal [ "C" ], Organization.in_city("l isle adam").pluck(:name)
  end

  test "without_website covers nil, blank and invalid values" do
    Organization.create!(name: "N", category: :b2b, website: nil)
    Organization.create!(name: "E", category: :b2b, website: "")
    Organization.create!(name: "OK", category: :b2b, website: "https://ok.test")

    assert_equal %w[E N], Organization.without_website.where(name: %w[N E OK]).pluck(:name).sort
    assert_equal [ "OK" ], Organization.with_website.where(name: %w[N E OK]).pluck(:name)
  end
end
