# 🕷️ Scrappeur

Application Rails de scraping B2B permettant de collecter des informations de contact (emails, téléphones, adresses) sur différentes catégories d'organisations en France, puis d'envoyer des campagnes d'emailing automatisées via l'API Brevo.

---

## ⚙️ Stack technique

- **Ruby** 3.4.2
- **Rails** 8.1.2
- **Base de données** SQLite3
- **Serveur web** Puma
- **File de jobs** Solid Queue
- **Scraping** Nokogiri, HTTParty, Ferrum (navigateur headless via Chrome)
- **Emailing** Brevo API (ex-Sendinblue)
- **Déploiement** Docker / Kamal

---

## 📦 Installation

```bash
git clone <repo-url>
cd Scrappeur

bundle install

cp .env.example .env   # Renseigner les variables d'environnement

rails db:create db:migrate

rails s
```

---

## 🔑 Variables d'environnement

Créer un fichier `.env` à la racine avec les clés suivantes :

```env
BREVO_API_KEY=your_brevo_api_key
```

---

## 🗂️ Catégories supportées

| Catégorie       | Source              | Description                        |
|-----------------|---------------------|------------------------------------|
| `:school`       | API Gouvernementale | Écoles par département             |
| `:medical`      | Google Maps         | Médecins, cliniques, pharmacies    |
| `:b2b`          | Google Maps         | Entreprises (avocats, comptables…) |
| `:association`  | Google Maps         | Associations                       |
| `:accommodation`| Google Maps         | Hôtels, hébergements               |
| `:coach`        | Google Maps         | Coachs sportifs                    |
| `:restaurant`   | Google Maps         | Restaurants                        |
| `:town_hall`    | Scraper dédié       | Mairies                            |

---

## 🚀 Lancer un scraping

Ouvrir la console Rails :

```bash
rails console
```

### Écoles (API gouvernementale — rapide)

```ruby
ScrapeOpenDataJob.perform_now(:school, "75")   # par numéro de département
```

### Toutes les autres catégories (Google Maps — lent mais précis)

```ruby
ScrapeOpenDataJob.perform_now(:b2b,            "Avocat",        "Lyon")
ScrapeOpenDataJob.perform_now(:b2b,            "Comptable",     "Paris")
ScrapeOpenDataJob.perform_now(:medical,        "Médecin",       "Marseille")
ScrapeOpenDataJob.perform_now(:association,    "Association",   "Bordeaux")
ScrapeOpenDataJob.perform_now(:accommodation,  "Hotel",         "Toulouse")
ScrapeOpenDataJob.perform_now(:coach,          "Coach sportif", "Nantes")
ScrapeOpenDataJob.perform_now(:restaurant,     "Restaurant",    "Lyon")
```

---

## 📧 Lancer une campagne emailing

```ruby
# Toutes les organisations prêtes à être contactées (limite 100 par défaut)
SendEmailCampaignJob.perform_now

# Filtrer par catégorie
SendEmailCampaignJob.perform_now(category: :b2b, limit: 50)
SendEmailCampaignJob.perform_now(category: :medical, limit: 200)
```

> ℹ️ Un délai de 4 secondes entre chaque envoi est respecté pour rester sous la limite Brevo (~300 mails/jour).

---

## 🏗️ Architecture

```
app/
├── jobs/
│   ├── scrape_open_data_job.rb       # Orchestre le scraping par catégorie
│   └── send_email_campaign_job.rb    # Orchestre les envois d'emails
├── services/
│   ├── scrapers/
│   │   ├── google_maps_service.rb    # Scraping Google Maps (Ferrum headless)
│   │   ├── open_data_api_service.rb  # API gouvernementale (écoles)
│   │   └── headless_browser_service.rb
│   ├── mailers/
│   │   ├── brevo_service.rb          # Appel à l'API Brevo
│   │   └── templates.rb             # Templates d'emails par catégorie
│   └── town_hall_scraper.rb         # Scraper dédié aux mairies
└── models/
    ├── organization.rb               # Modèle principal (contacts scrapés)
    └── town_hall.rb
```

---

## 🗄️ Modèle `Organization`

| Champ            | Description                                  |
|------------------|----------------------------------------------|
| `name`           | Nom de l'organisation                        |
| `email`          | Adresse email                                |
| `phone`          | Téléphone                                    |
| `address`        | Adresse postale                              |
| `website`        | Site web                                     |
| `category`       | Catégorie (enum)                             |
| `email_sent_at`  | Date du dernier envoi d'email                |
| `unsubscribed_at`| Date de désinscription (RGPD)               |

---

## 📋 Scopes utiles (console)

```ruby
Organization.with_email.count          # Contacts avec email valide
Organization.ready_to_contact.count    # Prêts à être contactés
Organization.where(category: :b2b)     # Filtrer par catégorie
```

---

## 🐳 Déploiement (Docker / Kamal)

```bash
kamal deploy
```

---

## ⚖️ Conformité RGPD

- Les emails collectés sont issus de sources publiques (Google Maps, API gouvernementale).
- Un mécanisme de désinscription (`unsubscribed_at`) est intégré pour respecter les demandes de suppression.
- Aucune donnée personnelle privée n'est collectée.
