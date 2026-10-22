require "test_helper"

class GoogleMapsServiceTest < ActiveSupport::TestCase
  test "matches normalized business names from a Maps listing" do
    assert Scrapers::GoogleMapsService.maps_place_match?("COMBETTES BTP", "Combettes BTP - Pont-de-Salars")
    assert Scrapers::GoogleMapsService.maps_place_match?(
      "La Colline du Chat Perche Sophrolo-gîtes : Gîte avec spa, tout confort",
      "La Colline du Chat Perché"
    )
  end

  test "rejects a different Maps listing with a similar category" do
    assert_not Scrapers::GoogleMapsService.maps_place_match?("Soucasse Travaux Publics", "Soucasse Transports")
    assert_not Scrapers::GoogleMapsService.maps_place_match?("COMBETTES BTP", "Combettes Immobilier")
  end

  test "rejects missing Maps names" do
    assert_not Scrapers::GoogleMapsService.maps_place_match?("Entreprise", nil)
    assert_not Scrapers::GoogleMapsService.maps_place_match?("", "Entreprise")
  end
end
