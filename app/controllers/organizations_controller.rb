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
    organization = Organization.find_by(id: params[:id])
    if organization
      organization.destroy
      redirect_back fallback_location: root_path, notice: "Contact supprimé."
    else
      redirect_back fallback_location: root_path, alert: "Organisation introuvable."
    end
  end
end
