class Organization < ApplicationRecord
  validates :website, format: { with: /\Ahttps?:\/\/\S+\z/i, allow_blank: true }

  enum :category, {
    school: 0,
    medical: 1,
    b2b: 2,
    association: 3,
    accommodation: 4,
    coach: 5,
    town_hall: 6,
    restaurant: 7
  }

  validates :name, presence: true

  WEBSITE_SQL = "website LIKE 'http://%' OR website LIKE 'https://%'".freeze

  # Ignore casse, accents, tirets et apostrophes ("Pont-de-Salars" == "pont de salars").
  def self.normalize_place(value)
    value.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase.gsub(/[^a-z0-9]+/, " ").strip
  end

  def self.in_city(term)
    needle = normalize_place(term)
    return all if needle.empty?

    where(city: distinct.pluck(:city).compact.select { |city| normalize_place(city).include?(needle) })
  end

  scope :with_website, -> { where(WEBSITE_SQL) }
  scope :without_website, -> { where.not(WEBSITE_SQL).or(where(website: nil)) }

  scope :with_email, -> { where.not(email: [ nil, "" ]).where("email LIKE ?", "%@%").where.not("email LIKE ?", "Visiter:%").where.not("email LIKE ?", "Tél:%") }
  scope :not_contacted, -> { where(email_sent_at: nil) }
  scope :not_unsubscribed, -> { where(unsubscribed_at: nil) }
  scope :ready_to_contact, -> { with_email.not_contacted.not_unsubscribed }
end
