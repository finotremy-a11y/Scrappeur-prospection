require "csv"

class ProspectingController < ApplicationController
  CATEGORY_LABELS = {
    "b2b" => "BTP / Entreprises",
    "restaurant" => "Restaurant",
    "medical" => "Médical",
    "association" => "Association",
    "accommodation" => "Hébergement",
    "coach" => "Coach",
    "school" => "École",
    "town_hall" => "Mairie"
  }.freeze

  before_action :load_categories

  def index
  end

  def create
    city = params[:city].to_s.strip
    category = params[:category].to_s.strip

    if city.blank? || !Organization.categories.key?(category)
      redirect_to prospecting_path, alert: "Veuillez renseigner une ville et un secteur valide."
      return
    end

    result = ProspectingScanService.new(city: city, category: category).call
    session[:prospecting_filters] = { "city" => city, "category" => category }
    session[:prospecting_errors] = result.errors
    session[:prospecting_skipped] = result.skipped_count
    redirect_to prospecting_results_path
  end

  def results
    filters = session[:prospecting_filters] || {}
    @city = filters["city"]
    @category = filters["category"]
    @organizations = filtered_organizations
    @scan_errors = session.delete(:prospecting_errors) || []
    @skipped_count = session.delete(:prospecting_skipped).to_i
  end

  def export
    filters = session[:prospecting_filters] || {}
    organizations = filtered_organizations(filters).limit(10)

    csv = CSV.generate(headers: true) do |output|
      output << %w[name category city website http_status load_time_sec is_https cms_detected has_form lead_score]
      organizations.each do |organization|
        output << [
          organization.name, organization.category, organization.city, organization.website,
          organization.http_status, organization.load_time_sec, organization.is_https,
          organization.cms_detected, organization.has_form, organization.lead_score
        ]
      end
    end

    send_data csv, filename: "feuille_de_route_#{Date.current}.csv", type: "text/csv"
  end

  private

  def filtered_organizations(filters = session[:prospecting_filters] || {})
    scope = Organization.in_city(filters["city"]).where(category: filters["category"]).with_website
    scope = scope.select { |o| WebsiteAnalyzer.valid_url?(o.website) }.map(&:id)
    Organization.where(id: scope).order(lead_score: :desc, name: :asc)
  end

  def load_categories
    @categories = Organization.categories.keys.map { |key| [ CATEGORY_LABELS.fetch(key, key.humanize), key ] }
  end
end
