require "uri"

# Décide si une URL peut être enregistrée comme site officiel d'une entreprise.
class WebsiteUrlPolicy
  BLOCKED_DOMAINS = %w[
    facebook.com instagram.com linkedin.com twitter.com x.com youtube.com tiktok.com pinterest.com
    google.com google.fr goo.gl g.page bing.com duckduckgo.com wikipedia.org
    pagesjaunes.fr yelp.fr yelp.com tripadvisor.fr tripadvisor.com mappy.com 118000.fr 118712.fr
    societe.com pappers.fr verif.com manageo.fr infogreffe.fr europages.fr kompass.com
    thefork.fr lafourchette.com restaurantguru.com wheree.com reserver-table.fr
    booking.com airbnb.fr airbnb.com expedia.fr abritel.fr gites-de-france.com
    tourisme-aveyron.com visit-occitanie.com sortie-visite.com autour-de-moi.com logishotels.com
    annuaire-mairie.fr annuaire-des-mairies.com annuaire-education.fr ecolesprimaires.fr
    leboncoin.fr meteo60.fr myboulange.fr lesgarages.fr rdvgarageauto.fr sante.fr lemedecin.fr maiia.com doctolib.fr
    fr-occitanie.fr strasbourghotel24.com allogarage.fr lilletourism.com hotelstrasbourg.org hotels-midi-pyrenees.com midi-pyrenees-hotels.com
  ].freeze

  GENERIC_WORDS = %w[
    le la les l un une de du des d et en au aux sur sous chez pour
    sarl sas sasu eurl sa snc ets
    restaurant resto camping hotel gite gites chambre chambres bar cafe brasserie pizzeria boulangerie patisserie
    cabinet entreprise societe groupe services service garage garages auto automobile automobiles
    medical medicale medecin medecine docteur dr centre maison sante hotel hotels ibis budget
  ].freeze

  # Au-delà, un même domaine déjà attribué à d'autres fiches Google Maps est considéré comme un annuaire.
  MAX_OTHER_ORGANIZATIONS_PER_HOST = 2
  MIN_TOKEN_LENGTH = 3

  class << self
    def host_of(url)
      URI.parse(url.to_s.strip).host.to_s.downcase.delete_prefix("www.").presence
    rescue URI::InvalidURIError
      nil
    end

    def blocked?(url)
      host = host_of(url)
      return true if host.nil?

      BLOCKED_DOMAINS.any? { |domain| host == domain || host.end_with?(".#{domain}") }
    end

    # true si le nom de l'entreprise apparaît dans le domaine ou, à défaut, dans la page d'accueil.
    # Sans page (html nil) et sans correspondance dans le domaine, on ne peut pas juger : on accepte,
    # sauf en mode strict (candidat issu d'une recherche, sans aucune autre preuve).
    def relevant?(url, name:, html: nil, strict: false)
      tokens = name_tokens(name)
      host = host_of(url)
      return false if host.nil?
      return true if tokens.empty?

      compact_host = normalize(host).delete(" ")
      return true if tokens.any? { |token| compact_host.include?(token) }
      return !strict if html.nil?

      page = normalize(page_signature(html))
      return true if page.include?(normalize(name))

      matches = tokens.count { |token| page.include?(token) }
      matches >= [ (tokens.size / 2.0).ceil, 1 ].max
    end

    def domain_match?(url, name)
      compact_host = normalize(host_of(url)).delete(" ")
      name_tokens(name).any? { |token| compact_host.include?(token) }
    end

    def exact_name_match?(url, name, html)
      tokens = name_tokens(name)
      compact_host = normalize(host_of(url)).delete(" ")
      return true if tokens.any? && tokens.all? { |token| compact_host.include?(token) }

      page = Nokogiri::HTML(html.to_s)
      signature = normalize([ page.at_css("title")&.text, page.css("h1, h2").map(&:text) ].flatten.join(" "))
      signature.include?(normalize(name))
    end

    def shared?(url, except: nil)
      host = host_of(url)
      return false if host.nil?

      scope = Organization.where(source: "Google Maps").where("website LIKE ?", "%#{Organization.sanitize_sql_like(host)}%")
      scope = scope.where.not(id: except.id) if except&.persisted?
      scope.where.not(name: except&.name).count >= MAX_OTHER_ORGANIZATIONS_PER_HOST
    end

    # Renvoie [true, nil] ou [false, "raison"].
    # strict: pour un site trouvé par recherche, le nom doit apparaître dans le domaine ou intégralement dans la page.
    def check(url, name:, html: nil, organization: nil, strict: false)
      return [ false, "aucune URL" ] if url.to_s.strip.empty?
      return [ false, "domaine d'annuaire ou d'agrégateur" ] if blocked?(url)
      if shared?(url, except: organization) && !domain_match?(url, name)
        return [ false, "domaine déjà utilisé par d'autres entreprises" ]
      end
      return [ false, "le site ne semble pas correspondre à l'entreprise" ] unless relevant?(url, name: name, html: html)
      return [ false, "nom de l'entreprise introuvable sur le site" ] if strict && !exact_name_match?(url, name, html)

      [ true, nil ]
    end

    private

    def name_tokens(name)
      normalize(name).split.reject { |word| word.length < MIN_TOKEN_LENGTH || GENERIC_WORDS.include?(word) }.uniq
    end

    def normalize(value)
      Organization.normalize_place(value)
    end

    def page_signature(html)
      document = Nokogiri::HTML(html.to_s)
      [ document.at_css("title")&.text, document.css("h1, h2").map(&:text).first(5), document.at_css("body")&.text.to_s[0, 5000] ].flatten.join(" ")
    end
  end
end
