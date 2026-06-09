class ScrapeOpenDataJob < ApplicationJob
  queue_as :default

  # Usage:
  #   Schools (API):  ScrapeOpenDataJob.perform_now(:school, "75")
  #   Google Maps:    ScrapeOpenDataJob.perform_now(:b2b, "Avocat", "Lyon")
  def perform(category, query_or_department, location = nil)
    puts "Starting job: #{category} | #{query_or_department} | #{location}"

    case category.to_sym
    when :school
      Scrapers::OpenDataApiService.fetch_schools(query_or_department)
    when :medical
      Scrapers::GoogleMapsService.scrape(:medical, query_or_department || "Médecin", location || query_or_department)
    when :b2b
      Scrapers::GoogleMapsService.scrape(:b2b, query_or_department || "Entreprise", location || query_or_department)
    when :association
      Scrapers::GoogleMapsService.scrape(:association, query_or_department || "Association", location || query_or_department)
    when :accommodation
      Scrapers::GoogleMapsService.scrape(:accommodation, query_or_department || "Hébergement", location || query_or_department)
    when :coach
      Scrapers::GoogleMapsService.scrape(:coach, query_or_department || "Coach", location || query_or_department)
    when :restaurant
      Scrapers::GoogleMapsService.scrape(:restaurant, query_or_department || "Restaurant", location || query_or_department)
    else
      Rails.logger.warn "Category #{category} not supported yet"
    end

    puts "Finished job for #{category}."
  end
end
