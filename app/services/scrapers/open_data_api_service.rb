module Scrapers
  class OpenDataApiService
    include HTTParty

    def self.fetch_schools(department_code)
      puts "Fetching schools for department #{department_code} from OpenData API..."
      # API endpoint for French Education Ministry Open Data
      url = "https://data.education.gouv.fr/api/explore/v2.1/catalog/datasets/fr-en-annuaire-education/records"
      
      # Using the standard refine parameter for API v2.1
      query = { limit: 100 }
      if department_code.present?
        formatted_code = department_code.to_s.rjust(3, "0")
        query[:refine] = "code_departement:#{formatted_code}"
      end

      begin
        response = get(url, query: query)
        
        if response.success?
          records = response.parsed_response["results"] || []
          valid_count = 0
          
          records.each do |school|
            email = school["mail"]
            name = school["nom_etablissement"]
            city = school["nom_commune"]
            
            if email.present?
              org = Organization.find_or_initialize_by(name: name, category: :school)
              org.source = "Data.education.gouv.fr"
              org.city = city
              org.department = department_code
              org.email = email if org.email.blank? || !org.email.match?(/@/)
              org.save!
              valid_count += 1
            end
          end
          puts "=> Success! Saved #{valid_count} schools with emails for department #{department_code}."
        else
          puts "Error fetching API: #{response.code} - #{response.body}"
        end
      rescue => e
        puts "Exception during API call: #{e.message}"
      end
    end
  end
end
