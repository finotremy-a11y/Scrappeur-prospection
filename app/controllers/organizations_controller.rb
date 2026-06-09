class OrganizationsController < ApplicationController
  def index
    @organizations = Organization.order(created_at: :desc)
    
    if params[:category].present?
      @organizations = @organizations.where(category: params[:category])
    end

    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @organizations = @organizations.where("name LIKE ? OR department LIKE ? OR city LIKE ?", search_term, search_term, search_term)
    end
    @organizations = @organizations.page(params[:page]).per(100)
  end

  def destroy
    Organization.find(params[:id]).destroy
    redirect_back fallback_location: root_path, notice: "Contact supprimé."
  end
end
