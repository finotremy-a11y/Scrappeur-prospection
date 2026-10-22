require "csv"
require "cgi"
require "net/http"
require "nokogiri"
require "openssl"
require "timeout"
require "uri"

module UrlEnrichment
  RAW_PATH = Rails.root.join("prospects.csv")
  ENRICHED_PATH = Rails.root.join("prospects_enrichis_complet.csv")
  SEARCH_URL = "https://html.duckduckgo.com/html/".freeze
  USER_AGENT = "Mozilla/5.0 (compatible; ProspectURLFinder/1.0)".freeze
  LOG_EVERY = 50
  IGNORED_DOMAINS = %w[
    facebook.com pagesjaunes.fr yelp.fr yelp.com tripadvisor.fr tripadvisor.com societe.com
    instagram.com linkedin.com twitter.com x.com youtube.com wikipedia.org mappy.com
    google.com google.fr bing.com duckduckgo.com annuaire-mairie.fr annuaire-des-mairies.com
    infogreffe.fr restaurantguru.com wheree.com thefork.fr pappers.fr verif.com manageo.fr europages.fr kompass.com
  ].freeze
  NAME_HEADERS = [ "name", "nom", "nom de l'entreprise", "entreprise" ].freeze
  CITY_HEADERS = [ "city", "ville", "commune" ].freeze
  DEPARTMENT_HEADERS = [ "department", "dpt", "departement", "département" ].freeze
  URL_HEADERS = [ "website", "website_url", "url", "site" ].freeze
  IGNORED_DOMAIN_LABELS = %w[facebook pagesjaunes yelp tripadvisor societe].freeze

  module_function

  def find_header(headers, candidates)
    headers.find { |header| candidates.include?(header.to_s.strip.downcase) }
  end

  def ignored?(host)
    host = host.to_s.downcase.delete_prefix("www.")
    labels = host.split(".")
    IGNORED_DOMAIN_LABELS.any? { |label| labels.include?(label) } ||
      IGNORED_DOMAINS.any? { |domain| host == domain || host.end_with?(".#{domain}") } ||
      WebsiteUrlPolicy.blocked?("https://#{host}/")
  end

  def official_url?(value)
    WebsiteAnalyzer.valid_url?(value) && !ignored?(URI.parse(value).host)
  rescue URI::InvalidURIError
    false
  end

  def search(query)
    uri = URI(SEARCH_URL)
    uri.query = URI.encode_www_form(q: query)
    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = USER_AGENT
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 15) { |http| http.request(request) }
    return nil unless response.is_a?(Net::HTTPSuccess)

    Nokogiri::HTML(response.body).css("a.result__a").filter_map do |link|
      href = link["href"].to_s
      href = "https:#{href}" if href.start_with?("//")
      target = CGI.parse(URI(href).query.to_s)["uddg"].first || href
      uri = URI.parse(target)
      target if WebsiteAnalyzer.valid_url?(target) && !ignored?(uri.host)
    rescue URI::InvalidURIError
      nil
    end
  rescue SocketError, Net::OpenTimeout, Net::ReadTimeout, Timeout::Error,
         OpenSSL::SSL::SSLError, URI::InvalidURIError, SystemCallError, EOFError, IOError => e
    warn "Recherche échouée (#{query}): #{e.class} #{e.message}"
    nil
  end

  def fetch_html(url)
    uri = URI.parse(url)
    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = USER_AGENT
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 7, read_timeout: 10) { |http| http.request(request) }
    response.is_a?(Net::HTTPSuccess) ? response.body.to_s : nil
  rescue StandardError, Timeout::Error
    nil
  end

  def root_url(url)
    uri = URI.parse(url)
    "#{uri.scheme}://#{uri.host}/"
  end
end

namespace :prospects do
  desc "Exporte les organisations de la base vers prospects.csv (CATEGORY=restaurant pour filtrer)"
  task export_raw: :environment do
    scope = Organization.order(:id)
    scope = scope.where(category: ENV["CATEGORY"]) if ENV["CATEGORY"].present?
    CSV.open(UrlEnrichment::RAW_PATH, "wb", write_headers: true, headers: %w[id name category city department website]) do |csv|
      scope.find_each { |o| csv << [ o.id, o.name, o.category, o.city, o.department, o.website ] }
    end
    puts "#{scope.count} lignes exportées vers #{UrlEnrichment::RAW_PATH}"
  end

  desc "Enrichit prospects.csv avec les URLs manquantes -> prospects_enrichis_complet.csv (INPUT=, OUTPUT=, LIMIT=). Reprenable."
  task enrich_urls: :environment do
    input = ENV.fetch("INPUT", UrlEnrichment::RAW_PATH.to_s)
    output = ENV.fetch("OUTPUT", UrlEnrichment::ENRICHED_PATH.to_s)
    limit = ENV["LIMIT"]&.to_i
    abort "Fichier introuvable : #{input} (lancez d'abord prospects:export_raw)" unless File.exist?(input)

    table = CSV.read(input, headers: true)
    headers = table.headers
    name_h = UrlEnrichment.find_header(headers, UrlEnrichment::NAME_HEADERS) or abort "Colonne nom introuvable"
    city_h = UrlEnrichment.find_header(headers, UrlEnrichment::CITY_HEADERS)
    dept_h = UrlEnrichment.find_header(headers, UrlEnrichment::DEPARTMENT_HEADERS)
    url_h = UrlEnrichment.find_header(headers, UrlEnrichment::URL_HEADERS)
    out_headers = url_h ? headers : headers + [ "website" ]
    url_h ||= "website"

    # The output itself is the checkpoint: a restart preserves valid URLs and retries failed lookups.
    done = File.exist?(output) ? CSV.read(output, headers: true).map(&:to_h) : []
    processed = 0
    searched = 0
    found = 0

    CSV.open(output, "wb", write_headers: true, headers: out_headers) do |csv|
      table.each_with_index do |row, index|
        previous_url = done[index]&.fetch(url_h, nil).to_s.strip
        url = UrlEnrichment.official_url?(previous_url) ? previous_url : row[url_h].to_s.strip
        unless WebsiteAnalyzer.valid_url?(url)
          break if limit && searched >= limit

          url = ""
          query = [ row[name_h], row[city_h], row[dept_h] ].compact.map(&:to_s).reject(&:empty?).join(" ")
          candidate = UrlEnrichment.search(query)&.find do |result|
            WebsiteUrlPolicy.relevant?(result, name: row[name_h], strict: true)
          end
          if candidate
            url = UrlEnrichment.root_url(candidate)
            found += 1
          end
          searched += 1
          sleep 1
        end

        fields = row.to_h
        fields[url_h] = url
        csv << out_headers.map { |h| fields[h] }
        csv.flush
        processed += 1
        puts "#{index + 1}/#{table.size} traitées — #{found} URLs trouvées sur #{searched} recherches" if (index + 1) % UrlEnrichment::LOG_EVERY == 0
      end
    end
    puts "Terminé : #{processed} lignes écrites, #{found} URLs trouvées -> #{output}"
    Rake::Task["prospects:import_enriched"].invoke if !limit && processed == table.size
  end

  desc "Importe les URLs valides de prospects_enrichis_complet.csv dans la base (par id)"
  task import_enriched: :environment do
    path = ENV.fetch("INPUT", UrlEnrichment::ENRICHED_PATH.to_s)
    abort "Fichier introuvable : #{path}" unless File.exist?(path)

    updated = 0
    url_header = UrlEnrichment.find_header(CSV.open(path, &:readline), UrlEnrichment::URL_HEADERS)
    abort "Colonne URL introuvable dans #{path}" unless url_header
    existing_urls = Organization.pluck(:id, :website).to_h

    CSV.foreach(path, headers: true) do |row|
      next unless row["id"].present?

      id = row["id"].to_i
      current_url = existing_urls[id]
      imported_url = row[url_header].to_s.strip
      if UrlEnrichment.official_url?(imported_url)
        next if UrlEnrichment.official_url?(current_url)

        scope = Organization.where(id: id)
        scope = current_url.present? ? scope.where(website: current_url) : scope.where(website: [ nil, "" ])
        updated += scope.update_all(website: imported_url)
      elsif current_url.present? && !UrlEnrichment.official_url?(current_url)
        updated += Organization.where(id: id, website: current_url).update_all(website: nil)
      end
    end
    puts "#{updated} organisations mises à jour"
  end

  desc "Retire les URLs des fiches Google Maps refusées par WebsiteUrlPolicy (APPLY=1 pour appliquer, sinon simulation)"
  task clean_maps_urls: :environment do
    apply = ENV["APPLY"] == "1"
    rejected = Organization.where(source: "Google Maps").with_website.filter_map do |organization|
      ok, reason = WebsiteUrlPolicy.check(organization.website, name: organization.name, organization: organization)
      [ organization, reason ] unless ok
    end

    rejected.each { |organization, reason| puts "#{organization.id} | #{organization.name.slice(0, 40)} | #{organization.website} | #{reason}" }
    if apply
      Organization.where(id: rejected.map { |organization, _| organization.id }).update_all(website: nil)
      puts "#{rejected.size} URLs retirées"
    else
      puts "#{rejected.size} URLs seraient retirées (relancez avec APPLY=1)"
    end
  end

  desc "Cherche les URLs manquantes des fiches Google Maps, validées par WebsiteUrlPolicy (LIMIT=, DRY_RUN=1)"
  task refind_maps_urls: :environment do
    limit = ENV.fetch("LIMIT", "50").to_i
    scope = Organization.where(source: "Google Maps").where(website: [ nil, "" ]).order(:id).limit(limit)
    found = 0

    scope.each do |organization|
      query = [ organization.name, organization.city ].compact_blank.join(" ")
      candidates = UrlEnrichment.search(query).to_a.map { |url| UrlEnrichment.root_url(url) }.uniq.first(5)
      accepted = candidates.find do |url|
        html = UrlEnrichment.fetch_html(url)
        html && WebsiteUrlPolicy.check(url, name: organization.name, html: html, organization: organization, strict: true).first
      end
      sleep 1

      if accepted
        found += 1
        organization.update!(website: accepted) unless ENV["DRY_RUN"] == "1"
        puts "OK  #{organization.name} -> #{accepted}"
      else
        puts "—   #{organization.name} (aucun site fiable)"
      end
    end
    puts "#{found}/#{scope.size} URLs retrouvées"
  end

  desc "Recherche les sites manquants depuis les fiches Google Maps (LIMIT=20, OFFSET=0, DRY_RUN=1)"
  task refind_maps_urls_from_google_maps: :environment do
    require "ferrum"

    limit = ENV.fetch("LIMIT", "20").to_i
    offset = ENV.fetch("OFFSET", "0").to_i
    scope = Organization.where(source: "Google Maps").where(website: [ nil, "" ]).order(:id).offset(offset).limit(limit)
    browser = Ferrum::Browser.new(
      headless: true,
      timeout: 30,
      window_size: [ 1280, 900 ],
      browser_options: {
        'no-sandbox': nil,
        'disable-setuid-sandbox': nil,
        'user-agent': "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/123.0.0.0 Safari/537.36"
      }
    )
    found = 0

    begin
      browser.goto("https://www.google.fr")
      sleep 2
      browser.cookies.set(name: "SOCS", value: Scrapers::GoogleMapsService::SOCS_COOKIE, domain: ".google.fr")
      browser.cookies.set(name: "CONSENT", value: "PENDING+987", domain: ".google.fr")

      scope.each do |organization|
        begin
          match = Scrapers::GoogleMapsService.find_website_on_maps(browser, organization)
          unless match
            puts "—   #{organization.name} (aucune fiche Maps correspondante avec un site)"
            next
          end

          website, place_name = match
          if website.blank?
            puts "—   #{organization.name} (fiche « #{place_name} » sans URL)"
            next
          end

          html = WebsiteUrlPolicy.domain_match?(website, organization.name) ? nil : Scrapers::GoogleMapsService.fetch_html(website)
          accepted, reason = WebsiteUrlPolicy.check(website, name: organization.name, html: html, organization: organization)
          unless accepted
            puts "—   #{organization.name} (site Maps écarté : #{reason})"
            next
          end

          found += 1
          organization.update!(website: website) unless ENV["DRY_RUN"] == "1"
          puts "OK  #{organization.name} — fiche « #{place_name} » -> #{website}"
        rescue Ferrum::Error, ActiveRecord::RecordInvalid, IOError, SystemCallError => e
          warn "Échec Google Maps pour #{organization.name} : #{e.class} #{e.message}"
        end
      end
    ensure
      browser.quit
    end

    puts "#{found}/#{scope.size} URL(s) Maps validées#{ENV["DRY_RUN"] == "1" ? " (simulation)" : ""}"
  end
end
