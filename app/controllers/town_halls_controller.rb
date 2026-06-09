class TownHallsController < ApplicationController
  def index
    if params[:search].present?
      @town_halls = TownHall.where("name LIKE ? OR department LIKE ?", "%#{params[:search]}%", "%#{params[:search]}%").order(:department, :name)
    else
      @town_halls = TownHall.order(:department, :name)
    end
  end
end
