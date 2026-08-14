class ScrapingsController < ApplicationController
  def index
    # Catégories avec leur mode de scraping
    @categories = [
      { key: "school",        label: "🏫 Écoles",        mode: :open_data,   placeholder_query: nil,         placeholder_location: "ex: 75 (code département)" },
      { key: "medical",       label: "🏥 Médical",        mode: :google_maps, placeholder_query: "ex: Médecin", placeholder_location: "ex: Lyon" },
      { key: "b2b",           label: "💼 B2B",            mode: :google_maps, placeholder_query: "ex: Avocat", placeholder_location: "ex: Paris" },
      { key: "association",   label: "🤝 Associations",   mode: :google_maps, placeholder_query: "ex: Association humanitaire", placeholder_location: "ex: Bordeaux" },
      { key: "accommodation", label: "🏨 Hébergements",   mode: :google_maps, placeholder_query: "ex: Hotel", placeholder_location: "ex: Toulouse" },
      { key: "coach",         label: "🏋️ Coachs",        mode: :google_maps, placeholder_query: "ex: Coach sportif", placeholder_location: "ex: Nantes" },
      { key: "restaurant",    label: "🍽️ Restaurants",   mode: :google_maps, placeholder_query: "ex: Restaurant", placeholder_location: "ex: Lyon" }
    ]
  end

  def create
    category  = params[:category].to_s.strip
    query     = params[:query].to_s.strip
    location  = params[:location].to_s.strip

    if category.blank?
      redirect_to scraping_index_path, alert: "Veuillez sélectionner une catégorie." and return
    end

    if category == "school"
      # L'école utilise l'API Open Data : seul le code département est nécessaire
      if location.blank?
        redirect_to scraping_index_path, alert: "Veuillez renseigner un code département pour les écoles." and return
      end
      ScrapeOpenDataJob.perform_later(:school, location)
      notice_msg = "Scraping des écoles pour le département #{location} lancé en arrière-plan !"
    else
      # Google Maps : requête + localisation
      if query.blank? || location.blank?
        redirect_to scraping_index_path, alert: "Veuillez remplir la requête et la localisation." and return
      end
      ScrapeOpenDataJob.perform_later(category.to_sym, query, location)
      notice_msg = "Scraping « #{query} » à « #{location} » (#{category}) lancé en arrière-plan !"
    end

    redirect_to scraping_index_path, notice: notice_msg
  end
end
