class Organization < ApplicationRecord
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

  scope :with_email, -> { where.not(email: [nil, '']).where("email LIKE ?", "%@%").where.not("email LIKE ?", "Visiter:%").where.not("email LIKE ?", "Tél:%") }
  scope :not_contacted, -> { where(email_sent_at: nil) }
  scope :not_unsubscribed, -> { where(unsubscribed_at: nil) }
  scope :ready_to_contact, -> { with_email.not_contacted.not_unsubscribed }
end
