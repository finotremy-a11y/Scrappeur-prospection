#!/usr/bin/env ruby
# frozen_string_literal: true

require "cgi"
require "csv"
require "net/http"
require "nokogiri"
require "openssl"
require "timeout"
require "uri"

class UrlFinder
  INPUT_PATH = "prospects.csv"
  OUTPUT_PATH = "prospects_avec_urls.csv"
  SEARCH_URL = "https://html.duckduckgo.com/html/"
  USER_AGENT = "Mozilla/5.0 (compatible; ProspectURLFinder/1.0)"
  REQUEST_DELAY_SECONDS = 2
  IGNORED_DOMAINS = %w[
    pagesjaunes.fr
    tripadvisor.fr
    tripadvisor.com
    yelp.fr
    yelp.com
    facebook.com
  ].freeze
  HEADER_ALIASES = {
    company: [ "nom de l'entreprise", "nom entreprise", "entreprise", "nom" ],
    city: [ "ville", "commune" ]
  }.freeze

  def initialize(input_path: INPUT_PATH, output_path: OUTPUT_PATH)
    @input_path = input_path
    @output_path = output_path
  end

  def run
    validate_input_file!
    table = CSV.read(@input_path, headers: true)
    headers = table.headers
    company_header = find_header(headers, :company)
    city_header = find_header(headers, :city)
    validate_headers!(company_header, city_header)

    website_index = headers.index("website_url")
    output_headers = website_index ? headers : headers + [ "website_url" ]

    CSV.open(@output_path, "wb", write_headers: true, headers: output_headers) do |output|
      table.each_with_index do |row, index|
        website_url, error = find_website(row[company_header], row[city_header])
        warn "Ligne #{index + 2}: #{error}" if error

        fields = row.fields
        if website_index
          fields[website_index] = website_url
        else
          fields << website_url
        end
        output << fields
      ensure
        sleep(REQUEST_DELAY_SECONDS) if index < table.length - 1
      end
    end

    puts "Recherche terminée : #{@output_path}"
  end

  private

  def validate_input_file!
    return if File.file?(@input_path)

    raise ArgumentError, "Fichier CSV introuvable : #{@input_path}"
  end

  def validate_headers!(company_header, city_header)
    return if company_header && city_header

    missing = []
    missing << "Nom de l'entreprise" unless company_header
    missing << "Ville" unless city_header
    raise ArgumentError, "Colonne(s) introuvable(s) : #{missing.join(', ')}"
  end

  def find_header(headers, kind)
    aliases = HEADER_ALIASES.fetch(kind).map { |header| normalize_header(header) }
    headers.find { |header| aliases.include?(normalize_header(header)) }
  end

  def normalize_header(header)
    header.to_s.encode("UTF-8", invalid: :replace, undef: :replace)
          .unicode_normalize(:nfkd)
          .delete("\u0300-\u036f")
          .downcase
          .gsub(/[^a-z0-9]/, "")
  end

  def find_website(company, city)
    company = company.to_s.strip
    city = city.to_s.strip
    return [ nil, "nom d'entreprise ou ville manquant(e)" ] if company.empty? || city.empty?

    query = URI.encode_www_form_component("#{company} #{city}")
    uri = URI.parse("#{SEARCH_URL}?q=#{query}")
    response = http_get(uri)
    return [ nil, "moteur de recherche HTTP #{response.code}" ] unless response.is_a?(Net::HTTPSuccess)

    url = extract_first_relevant_url(response.body)
    return [ url, nil ] if url

    [ nil, "aucune URL pertinente trouvée" ]
  rescue URI::InvalidURIError, SocketError, Net::OpenTimeout, Net::ReadTimeout, Timeout::Error => e
    [ nil, "requête impossible (#{e.class}: #{e.message})" ]
  rescue OpenSSL::SSL::SSLError, IOError => e
    [ nil, "erreur réseau (#{e.class}: #{e.message})" ]
  rescue Nokogiri::SyntaxError => e
    [ nil, "HTML illisible (#{e.message})" ]
  end

  def http_get(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 10
    http.read_timeout = 15
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER if http.use_ssl?

    request = Net::HTTP::Get.new(uri.request_uri)
    request["User-Agent"] = USER_AGENT
    request["Accept"] = "text/html,application/xhtml+xml"
    request["Accept-Language"] = "fr-FR,fr;q=0.9,en;q=0.8"
    http.request(request)
  end

  def extract_first_relevant_url(html)
    document = Nokogiri::HTML(html)
    document.css("a.result__a, .result__title a").each do |link|
      url = decode_result_url(link["href"])
      return url if relevant_url?(url)
    end
    nil
  end

  def decode_result_url(href)
    return if href.to_s.empty?

    href = "https:#{href}" if href.start_with?("//")
    uri = URI.parse(href)
    return CGI.parse(uri.query.to_s)["uddg"]&.first if uri.host&.end_with?("duckduckgo.com") && uri.path == "/l/"

    href
  rescue URI::InvalidURIError
    nil
  end

  def relevant_url?(url)
    uri = URI.parse(url.to_s)
    return false unless %w[http https].include?(uri.scheme) && uri.host

    host = uri.host.downcase.delete_prefix("www.")
    !IGNORED_DOMAINS.any? { |domain| host == domain || host.end_with?(".#{domain}") }
  rescue URI::InvalidURIError
    false
  end
end

if __FILE__ == $PROGRAM_NAME
  begin
    UrlFinder.new(
      input_path: ARGV.fetch(0, UrlFinder::INPUT_PATH),
      output_path: ARGV.fetch(1, UrlFinder::OUTPUT_PATH)
    ).run
  rescue ArgumentError => e
    warn e.message
    exit 1
  end
end
