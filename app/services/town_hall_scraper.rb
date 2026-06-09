class TownHallScraper
  require 'nokogiri'
  require 'open-uri'

  BASE_URL = "https://annuaire-des-mairies.com"

  def self.call(start_from: nil)
    new.call(start_from: start_from)
  end

  def call(start_from: nil)
    puts "Starting the scrape process of French Town Halls..."
    main_page = Nokogiri::HTML(URI.open(BASE_URL))
    
    department_links = main_page.css('a.lientxt').map { |a| { name: a.text.strip, url: a['href'] } }
    puts "Found #{department_links.count} departments to scrape."

    # Si un département de départ est spécifié, on saute les précédents
    if start_from.present?
      start_index = department_links.index { |d| d[:name].include?(start_from.to_s) }
      if start_index
        puts "Resuming from department '#{start_from}' (index #{start_index})..."
        department_links = department_links[start_index..]
      else
        puts "Département '#{start_from}' introuvable, scraping depuis le début."
      end
    end

    department_links.each_with_index do |dep, index|
      puts "[#{index + 1}/#{department_links.count}] Scraping department: #{dep[:name]}"
      scrape_department(dep)
      sleep 1
    end
    
    puts "Finished scraping all departments."
  end

  private

  def scrape_department(dep)
    dep_url = "#{BASE_URL}/#{dep[:url]}"
    
    begin
      dep_page = Nokogiri::HTML(URI.open(dep_url))
    rescue StandardError => e
      puts "  -> Error loading department #{dep[:name]} at #{dep_url}: #{e.message}"
      return
    end

    # Links to town halls are also 'a.lientxt' on department pages
    town_links = dep_page.css('a.lientxt').map { |a| { name: a.text.strip, url: a['href'] } }
    
    puts "  -> Found #{town_links.count} town halls."

    town_links.each do |town|
      scrape_town_hall(town, dep[:name])
      sleep 0.1
    end
  end

  def scrape_town_hall(town, department_name)
    town_path = town[:url]
    
    # Clean the relative path: replace './' with nothing, or remove leading '/'
    if town_path.start_with?("./")
      town_path = town_path[2..-1] 
    elsif town_path.start_with?("/")
      town_path = town_path[1..-1]
    end

    town_url = "#{BASE_URL}/#{town_path}"
    
    begin
      town_page = Nokogiri::HTML(URI.open(town_url))
    rescue StandardError => e
      puts "    -> Error loading town #{town[:name]} at #{town_url}: #{e.message}"
      return
    end

    # Extract email using regex on the main section text
    email = town_page.css('main').text.scan(/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/).first

    if email && !email.include?("annuaire-des-mairies.com")
      # Save to DB
      Organization.find_or_create_by!(name: town[:name], category: :town_hall) do |org|
        org.email = email
        org.department = department_name
        org.city = town[:name]
        org.source = "Annuaire des Mairies"
      end
      puts "    => Created/Updated #{town[:name]}: #{email}"
    else
      # Save even if no email is found, to avoid rescraping endlessly if we implement logic later
      Organization.find_or_create_by!(name: town[:name], category: :town_hall) do |org|
        org.department = department_name
        org.city = town[:name]
        org.source = "Annuaire des Mairies"
      end
      puts "    => No valid email found for #{town[:name]}"
    end
  end
end
