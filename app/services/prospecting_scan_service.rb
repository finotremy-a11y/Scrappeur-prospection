class ProspectingScanService
  Result = Struct.new(:organizations, :errors, :skipped_count, keyword_init: true)

  def initialize(city:, category:)
    @city = city.to_s.strip
    @category = category.to_s.strip
  end

  def call
    organizations = Organization.in_city(@city)
    organizations = organizations.where(category: @category) if Organization.categories.key?(@category)
    skipped_count = organizations.without_website.count

    errors = []
    organizations.find_each do |organization|
      next unless WebsiteAnalyzer.valid_url?(organization.website)

      analysis = WebsiteAnalyzer.new(organization.website).analyze
      organization.update!(
        http_status: analysis.http_status,
        load_time_sec: analysis.load_time_sec,
        is_https: analysis.is_https,
        cms_detected: analysis.cms_detected,
        has_form: analysis.has_form,
        has_conversion_keywords: analysis.has_conversion_keywords,
        lead_score: WebsiteAnalyzer.score(analysis)
      )
      errors << "#{organization.name}: #{analysis.error}" if analysis.error
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
      errors << "#{organization.name}: #{e.message}"
    end

    Result.new(organizations: organizations.with_website.order(lead_score: :desc, name: :asc), errors: errors, skipped_count: skipped_count)
  end
end
