require "net/http"
require "nokogiri"
require "openssl"
require "timeout"
require "uri"
require "ferrum"

class WebsiteAnalyzer
  TIMEOUT_SECONDS = 5
  MAX_REDIRECTS = 5
  USER_AGENT = "Scrappeur-WebsiteAnalyzer/1.0"
  CONVERSION_KEYWORDS = [ "réserver", "reserver", "devis", "prendre rendez-vous", "prendre rendez vous" ].freeze

  Result = Struct.new(
    :http_status, :load_time_sec, :is_https, :cms_detected, :has_form,
    :has_conversion_keywords, :error, keyword_init: true
  )

  HOST_PATTERN = /\A(?=.{1,253}\z)([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}\z/i

  def self.valid_url?(value)
    url = value.to_s.strip
    return false unless url.match?(/\Ahttps?:\/\//i)

    uri = URI.parse(url)
    %w[http https].include?(uri.scheme) && uri.host.to_s.match?(HOST_PATTERN)
  rescue URI::InvalidURIError
    false
  end

  def initialize(url)
    @url = url.to_s.strip
  end

  def analyze
    return failed_result("URL invalide : URL must use http or https and include a host") unless self.class.valid_url?(@url)

    response, final_uri, load_time = fetch
    result = Result.new(
      http_status: response.code.to_i, load_time_sec: load_time,
      is_https: final_uri.scheme == "https", cms_detected: nil,
      has_form: nil, has_conversion_keywords: false, error: nil
    )
    return result unless response.code.to_i == 200

    document = Nokogiri::HTML(response.body.to_s)
    page_text = document.text.gsub(/\s+/, " ").strip.downcase
    result.cms_detected = detect_cms(document, response.body.to_s)
    result.has_form = !document.css("form").empty?
    result.has_conversion_keywords = CONVERSION_KEYWORDS.any? { |keyword| page_text.include?(keyword) }
    result
  rescue URI::InvalidURIError, ArgumentError => e
    failed_result("URL invalide : #{e.message}")
  rescue OpenSSL::SSL::SSLError => e
    failed_result("Erreur SSL (#{e.class}) : #{e.message}")
  rescue SocketError, Errno::ECONNREFUSED => e
    failed_result("Erreur DNS ou connexion refusée (#{e.class}) : #{e.message}")
  rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error => e
    failed_result("Délai dépassé (#{TIMEOUT_SECONDS}s, #{e.class}) : #{e.message}")
  rescue Nokogiri::SyntaxError => e
    failed_result("HTML illisible (#{e.class}) : #{e.message}")
  rescue Ferrum::Error => e
    failed_result("Erreur Ferrum (#{e.class}) : #{e.message}")
  rescue EOFError, SystemCallError, IOError => e
    failed_result("#{e.class}: #{e.message}")
  end

  def self.score(result)
    score = 0
    score += 2 if result.is_https == false && (result.error.nil? || result.error.start_with?("Erreur SSL"))
    score += 2 if result.load_time_sec && result.load_time_sec > 4
    score += 3 if result.http_status && result.http_status >= 400
    score += 3 if result.has_form == false
    [ score, 10 ].min
  end

  UNKNOWN_CMS = "Développement sur-mesure / Inconnu".freeze

  private

  # Normalise le CMS sous la forme "CMS (Builder)"; nil si la page est vide.
  def detect_cms(document, html)
    source = html.downcase
    return nil if source.strip.empty?

    generator = document.at_xpath(
      "//meta[translate(@name, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz') = 'generator']"
    )&.[]("content").to_s.downcase

    # Wix/Webflow : uniquement dans les attributs des balises script, link et meta
    assets = document.xpath("//script[@src] | //link[@href] | //meta[@content]")
                     .flat_map { |node| %w[src href content].filter_map { |attr| node[attr] } }
                     .join(" ").downcase

    if source.include?("wp-content") || source.include?("wp-includes") || generator.include?("wordpress")
      return "WordPress (Elementor)" if source.include?("elementor") || generator.include?("elementor")
      return "WordPress (Divi)" if source.match?(/divi|et-builder/) || generator.include?("divi")

      "WordPress"
    elsif source.include?("prestashop") || source.include?("_ps_version_") || generator.include?("prestashop")
      "PrestaShop"
    elsif source.include?("cdn.shopify.com")
      "Shopify"
    elsif assets.include?("wix.com") || assets.include?("wixsite")
      "Wix"
    elsif assets.include?("webflow")
      "Webflow"
    elsif generator.include?("joomla")
      "Joomla"
    elsif generator.include?("drupal")
      "Drupal"
    else
      UNKNOWN_CMS
    end
  end

  def fetch
    parse_uri(@url)
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    browser = Ferrum::Browser.new(timeout: TIMEOUT_SECONDS)
    browser.go_to(@url)

    response = Struct.new(:code, :body).new(browser.network.status, browser.body)
    final_uri = parse_uri(browser.current_url)
    [ response, final_uri, elapsed(started_at) ]
  ensure
    browser&.quit
  end

  def request(uri, timeout_seconds)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = timeout_seconds
    http.read_timeout = timeout_seconds
    http.write_timeout = timeout_seconds if http.respond_to?(:write_timeout=)
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER if http.use_ssl?
    request = Net::HTTP::Get.new(uri.request_uri)
    request["User-Agent"] = USER_AGENT
    request["Accept"] = "text/html,application/xhtml+xml"
    http.request(request)
  end

  def parse_uri(value)
    uri = value.is_a?(URI) ? value : URI.parse(value)
    raise ArgumentError, "URL must use http or https and include a host" unless %w[http https].include?(uri.scheme) && uri.host
    uri
  end

  def elapsed(started_at)
    (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at).round(3)
  end

  def failed_result(message)
    Result.new(http_status: nil, load_time_sec: nil, is_https: false, cms_detected: nil,
               has_form: nil, has_conversion_keywords: false, error: message)
  end
end
