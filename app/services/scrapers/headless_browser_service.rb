module Scrapers
  class HeadlessBrowserService
    require 'ferrum'

    def self.scrape_pages_jaunes(category, query, location)
      puts "Starting headless scrape on PagesJaunes for '#{query}' in '#{location}'..."
      
      # Configuration de Ferrum avec options d'esquive basiques.
      # Attention: PagesJaunes utilise DataDome. En production intensive,
      # il faut configurer un proxy résidentiel (ex: proxy: { host: '..', port: .. })
      browser = Ferrum::Browser.new(
        headless: true,
        timeout: 25,
        window_size: [1280, 800],
        browser_options: {
          'no-sandbox': nil,
          'disable-setuid-sandbox': nil,
          'disable-blink-features': 'AutomationControlled',
          'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36'
        }
      )

      search_url = "https://www.pagesjaunes.fr/annuaire/chercherlespros?quoiqui=#{URI.encode_www_form_component(query)}&ou=#{URI.encode_www_form_component(location)}"

      begin
        browser.goto(search_url)
        sleep 4 # Attendre le chargement initial

        # 1. Gérer la bannière de cookies si présente
        accept_btn = browser.at_css('#didomi-notice-agree-button')
        if accept_btn
          accept_btn.click
          sleep 1
        end

        # 2. Récupérer les cartes de résultats
        cards = browser.css('.ZoneBi, .bi-pro, li.bi')
        
        if cards.empty?
          puts "Aucun résultat trouvé ou IP bloquée par le système antibot (DataDome)."
          return
        end

        puts "-> #{cards.size} résultats trouvés sur la page."
        saved_count = 0

        # 3. Parcourir chaque carte et extraire les données
        cards.each do |card|
          begin
            # Nom de l'entreprise
            name = card.at_css('.bi-denomination, h3, .denomination-links')&.text&.strip
            next unless name

            # Adresse
            address = card.at_css('.bi-address, .adresse')&.text&.strip
            
            # Essayer de cliquer sur le bouton "Afficher le N°" pour révéler le téléphone
            phone_btn = card.at_css('.number-contact, .pj-link')
            phone = nil
            if phone_btn
              phone_btn.click
              sleep 1 # Attendre l'animation/requête
              phone = card.at_css('.numero-telephone, .tel-contact')&.text&.strip
            else
              phone = card.at_css('.numero-telephone')&.text&.strip
            end

            # Vérifier s'il y a un lien direct vers l'email (rare) ou le site web
            website = card.at_css('.site-internet, a.site-web')&.attribute('href')
            
            found_email = nil
            if website.present?
              actual_site = website.start_with?('/') ? "https://www.pagesjaunes.fr#{website}" : website
              begin
                require 'httparty'
                # Certains sites bloquent HTTParty sans User-Agent
                headers = { 'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/114.0.0.0 Safari/537.36' }
                site_response = HTTParty.get(actual_site, headers: headers, timeout: 6, verify: false)
                
                # Si c'est une redirection PagesJaunes, on suit la redirection (HTTParty le fait par défaut)
                html = site_response.body.to_s
                
                # Regex pour trouver des emails
                emails = html.scan(/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b/i)
                valid_emails = emails.map(&:downcase).uniq.reject do |e| 
                  e.end_with?('.png', '.jpg', '.gif', 'sentry.io', 'example.com', '.webp', '.svg') || e.include?('rating@') || e.start_with?('contact@pagesjaunes')
                end
                found_email = valid_emails.first
              rescue => e
                puts "Impossible de scraper le site #{actual_site} : #{e.message}"
              end
            end

            final_email = found_email || phone || "Visiter: #{website}"

            # Trouver l'existant ou l'initialiser
            org = Organization.find_or_initialize_by(name: name, category: category)
            org.source = "PagesJaunes"
            org.city = location.titleize
            
            # Ne mettre à jour l'email que si on a trouvé un meilleur contact
            if org.email.blank? || org.email.start_with?('Visiter:') || org.email.match?(/^\d+$/)
              org.email = final_email
            end
            
            org.save!
            
            puts "   => Sauvegardé/Mis à jour: #{name} | Contact: #{final_email}"
            saved_count += 1
          rescue => e
            puts "Erreur parsing carte: #{e.message}"
            next
          end
        end
        
        puts "-> #{saved_count} organisations sauvegardées avec succès."
      rescue Ferrum::TimeoutError
        puts "Erreur : Timeout atteint. Probablement un captcha anti-bot."
      ensure
        browser.quit
      end
    end
  end
end
