require "test_helper"

class WebsiteUrlPolicyTest < ActiveSupport::TestCase
  test "blocks directories, aggregators and social networks" do
    %w[
      https://www.tourisme-aveyron.com/ https://www.facebook.com/camping https://fr.tripadvisor.com/x
      https://www.118000.fr/ https://www.pagesjaunes.fr/pros/1 https://gites-de-france.com/
    ].each { |url| assert WebsiteUrlPolicy.blocked?(url), url }
    assert_not WebsiteUrlPolicy.blocked?("https://www.clicochic.com/")
    assert WebsiteUrlPolicy.blocked?("pas une url")
  end

  test "relevant? matches the business name in the domain" do
    assert WebsiteUrlPolicy.relevant?("https://www.clicochic.com/", name: "Camping Clicochic - Soleil Levant")
    assert WebsiteUrlPolicy.relevant?("https://combelles-aveyron.fr/", name: "Domaine de Combelles - Village Vacances en Aveyron")
    assert_not WebsiteUrlPolicy.relevant?("https://www.autre-entreprise.fr/", name: "Soucasse Travaux Publics", html: "<title>Boulangerie</title>")
  end

  test "relevant? falls back on the home page content" do
    html = "<html><head><title>Soucasse Travaux Publics - Pont de Salars</title></head><body>Terrassement</body></html>"
    assert WebsiteUrlPolicy.relevant?("https://stp12.fr/", name: "Soucasse Travaux Publics", html: html)
  end

  test "relevant? accepts unknown domains without a page except in strict mode" do
    assert WebsiteUrlPolicy.relevant?("https://stp12.fr/", name: "Soucasse Travaux Publics")
    assert_not WebsiteUrlPolicy.relevant?("https://stp12.fr/", name: "Soucasse Travaux Publics", strict: true)
  end

  test "shared? flags a host already used by other Google Maps organizations" do
    2.times { |i| Organization.create!(name: "Autre #{i}", category: :b2b, source: "Google Maps", website: "https://annuaire-local.fr/") }
    candidate = Organization.new(name: "Nouvelle", category: :b2b)

    assert WebsiteUrlPolicy.shared?("https://annuaire-local.fr/", except: candidate)
    assert_not WebsiteUrlPolicy.shared?("https://autre-domaine.fr/", except: candidate)
  end

  test "shared? ignores government directories used by town halls and schools" do
    3.times { |i| Organization.create!(name: "Mairie #{i}", category: :town_hall, source: "Annuaire des Mairies", website: "https://lannuaire.service-public.gouv.fr/") }

    assert_not WebsiteUrlPolicy.shared?("https://lannuaire.service-public.gouv.fr/", except: Organization.new(name: "X"))
  end

  test "check returns a reason when the url is rejected" do
    ok, reason = WebsiteUrlPolicy.check("https://www.tourisme-aveyron.com/", name: "Camping du Lac")
    assert_not ok
    assert_match(/annuaire/, reason)

    ok, = WebsiteUrlPolicy.check("https://www.clicochic.com/", name: "Camping Clicochic")
    assert ok
  end

  test "strict check requires the business name in the domain or page title" do
    generic = "<title>Garages et réparation auto</title><body>Hérault Automobile cité en bas de page</body>"
    ok, reason = WebsiteUrlPolicy.check("https://www.reparations-rapides.fr/", name: "Hérault Automobile", html: generic, strict: true)
    assert_not ok
    assert_match(/introuvable/, reason)

    titled = "<title>Hérault Automobile - Garage à Béziers</title>"
    assert WebsiteUrlPolicy.check("https://garage-34.fr/", name: "Hérault Automobile", html: titled, strict: true).first
    assert WebsiteUrlPolicy.check("https://herault-automobile.fr/", name: "Hérault Automobile", html: generic, strict: true).first
  end

  test "a shared host is accepted when the business name is in the domain" do
    2.times { |i| Organization.create!(name: "Boutique #{i}", category: :b2b, source: "Google Maps", website: "https://polygone-beziers.fr/") }
    assert WebsiteUrlPolicy.check("https://polygone-beziers.fr/", name: "Polygone Béziers", organization: Organization.new(name: "Polygone Béziers")).first
  end
end
