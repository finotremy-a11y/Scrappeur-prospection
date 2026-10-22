module Scrapers
  class GoogleMapsService
    require "ferrum"
    require "httparty"

    SOCS_COOKIE = "CAISHAgBEhJnd3NfdHVzX3Ryb3BpY2FsGgIIcSABGgIIaw.."
    MAPS_MATCH_STOP_WORDS = %w[
      le la les l un une de du des d et en au aux sur sous chez pour btp sarl sas sasu eurl sa
      entreprise artisanale construction renovation gros oeuvre genie civil
    ].freeze

    def self.find_website_on_maps(browser, organization)
      query = URI.encode_www_form_component("#{organization.name} #{organization.city}")
      browser.goto("https://www.google.fr/maps/search/#{query}?hl=fr")
      sleep 4

      place_urls = if browser.current_url.include?("/maps/place/")
        [ browser.current_url ]
      else
        browser.css('a.hfpxzc, a[href*="/maps/place/"]')
               .map { |link| link.attribute("href") }.compact.uniq.first(5)
      end

      place_urls.each do |place_url|
        unless browser.current_url == place_url
          browser.goto(place_url)
          sleep 2
        end
        place_name = browser.at_css("h1")&.text&.strip
        next unless maps_place_match?(organization.name, place_name)

        website = browser.at_css('a[data-item-id="authority"]')&.attribute("href")
        return [ nil, place_name ] if website.blank? || website.include?("google.com")

        return [ website, place_name ]
      end

      nil
    end

    def self.maps_place_match?(expected_name, actual_name)
      expected = Organization.normalize_place(expected_name)
      actual = Organization.normalize_place(actual_name)
      return false if expected.blank? || actual.blank?
      return true if expected == actual || actual.include?(expected) || expected.include?(actual)

      expected_words = expected.split.reject { |word| MAPS_MATCH_STOP_WORDS.include?(word) || word.length < 3 }.uniq
      actual_words = actual.split.reject { |word| MAPS_MATCH_STOP_WORDS.include?(word) || word.length < 3 }.uniq
      overlap = (expected_words & actual_words).size
      return expected_words == actual_words unless expected_words.size > 1

      overlap >= 2 && overlap.to_f / expected_words.size >= 0.7
    end

    def self.scrape(category, query, location)
      puts "Starting Google Maps scrape for '#{query}' in '#{location}'..."

      browser = Ferrum::Browser.new(
        headless: true,
        timeout: 45,
        window_size: [ 1280, 900 ],
        browser_options: {
          'no-sandbox': nil,
          'disable-setuid-sandbox': nil,
          'disable-blink-features': "AutomationControlled",
          'user-agent': "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/123.0.0.0 Safari/537.36"
        }
      )

      begin
        # 1. Bypass Google Consent by setting cookies before navigating
        browser.goto("https://www.google.fr")
        sleep 2
        browser.cookies.set(name: "SOCS",    value: SOCS_COOKIE, domain: ".google.fr")
        browser.cookies.set(name: "CONSENT", value: "PENDING+987", domain: ".google.fr")

        # 2. Navigate to Google Maps search
        search_query = URI.encode_www_form_component("#{query} #{location}")
        browser.goto("https://www.google.fr/maps/search/#{search_query}?hl=fr")
        sleep 7

        # 3. Scroll the sidebar to load more results
        3.times do
          browser.evaluate("
            let feed = document.querySelector('div[role=\"feed\"]');
            if (feed) feed.scrollBy(0, 2000);
          ")
          sleep 2
        end

        # 4. Grab result card links
        cards = browser.css('a.hfpxzc, a[href*="/maps/place/"]')
        if cards.empty?
          puts "Aucun résultat tourvé pour '#{query}' à '#{location}'."
          return
        end

        links = cards.map { |c| c.attribute("href") }.compact.uniq.first(20)
        puts "-> #{links.size} fiches trouvées. Extraction en cours..."

        saved_count = 0

        links.each do |url|
          begin
            browser.goto(url)
            sleep 4

            # Name
            name = browser.at_css("h1")&.text&.strip
            next unless name.present?

            # Phone
            phone_el = browser.at_css('[data-item-id^="phone:"]')
            phone = phone_el&.text&.strip&.gsub(/[^0-9+ ]/, "")

            # Website (avoid google.com internal links)
            website_el = browser.at_css('a[data-item-id="authority"]')
            website = website_el&.attribute("href")
            website = nil if website&.include?("google.com")

            # Address
            address_el = browser.at_css('[data-item-id="address"]')
            address = address_el&.text&.strip

            # 5. Deep scrape the website for an email, then check the URL really belongs to this business
            website = unwrap_google_url(website)
            html = fetch_html(website)
            found_email = extract_email_from_html(html)

            org = Organization.find_or_initialize_by(name: name, category: category)
            if website.present?
              accepted, reason = WebsiteUrlPolicy.check(website, name: name, html: html, organization: org)
              unless accepted
                puts "     (Site écarté pour #{name}: #{reason} — #{website.to_s.slice(0, 60)})"
                website = nil
                found_email = nil
              end
            end

            final_email = found_email || ("Tél: #{phone}" if phone.present?) || (website.present? ? "Visiter: #{website}" : nil)

            if final_email.present?
              org.source = "Google Maps"
              org.city = location.titleize
              org.department = location
              org.website = website if website.present?

              if org.email.blank? || org.email.start_with?("Visiter:") || org.email.start_with?("Tél:")
                org.email = final_email
              end
              org.save!
              puts "   => Sauvegardé: #{name} | #{final_email}"
              saved_count += 1
            else
              puts "   => Ignoré: #{name} (aucun contact trouvé)"
            end

          rescue => e
            puts "Erreur extraction fiche #{url.to_s.slice(0, 60)}: #{e.message}"
            next
          end
        end

        puts "-> Terminé ! #{saved_count} enregistrements sauvegardés pour '#{query} #{location}'."

      rescue Ferrum::TimeoutError => e
        puts "Timeout global : #{e.message}"
      ensure
        browser.quit
      end
    end

    # Unwrap Google redirect URLs like /url?q=https://example.com&...
    def self.unwrap_google_url(url)
      return url unless url.to_s.start_with?("/url?q=") || url.to_s.include?("google.fr/url?q=")

      uri_match = url.match(/[?&]q=([^&]+)/)
      uri_match ? URI.decode_www_form_component(uri_match[1]) : url
    end

    def self.fetch_html(url)
      return nil unless url.to_s.start_with?("http")

      headers = { "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/123.0.0.0 Safari/537.36" }
      HTTParty.get(url, headers: headers, timeout: 7, verify: false, follow_redirects: true).body.to_s
    rescue => e
      puts "     (Impossible de scanner le site #{url.to_s.slice(0, 60)}: #{e.message})"
      nil
    end

    # Extracts the first valid email found in the HTML
    def self.extract_email_from_html(html)
      return nil if html.blank?

      emails = html.scan(/\b[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}\b/i)
      emails.map(&:downcase).uniq.reject do |e|
        e.end_with?(".png", ".jpg", ".gif", ".webp", ".svg") ||
        e.include?("sentry") || e.include?("wix") || e.include?("w3") ||
        e.start_with?("noreply@", "no-reply@") ||
        !e.include?("@")
      end.first
    end
  end
end
