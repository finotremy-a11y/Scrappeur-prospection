require "test_helper"

class TownHallsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get town_halls_index_url
    assert_response :success
  end
end
