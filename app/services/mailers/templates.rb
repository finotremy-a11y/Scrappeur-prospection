# Email templates for outreach campaigns
# Customize the subject and HTML body here freely.
module Mailers
  module Templates
    SUBJECT = {
      town_hall:    "Une solution numérique pour votre commune",
      school:       "Améliorez la communication avec vos familles",
      medical:      "Attirez de nouveaux patients en ligne",
      b2b:          "Développez votre clientèle avec le digital",
      association:  "Boostez la visibilité de votre association",
      accommodation: "Recevez plus de réservations directes",
      coach:        "Développez votre activité de coaching en ligne",
      restaurant:   "Remplissez vos tables grâce au digital",
    }.freeze

    def self.build(organization)
      category     = organization.category.to_sym
      subject      = SUBJECT[category] || "Une opportunité pour votre activité"
      name_display = organization.name.titleize
      body_html    = BODY_BY_CATEGORY[category] || BODY_BY_CATEGORY[:b2b]

      unsubscribe_url = "http://localhost:3000/unsubscribe/#{organization.id}"

      html = <<~HTML
        <!DOCTYPE html>
        <html lang="fr">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
            * { box-sizing: border-box; margin: 0; padding: 0; }
            body { font-family: 'Segoe UI', Arial, sans-serif; background: #f4f6f9; color: #1e293b; }
            .wrapper { max-width: 620px; margin: 32px auto; background: white; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.08); }
            .header { background: linear-gradient(135deg, #1d4ed8 0%, #7c3aed 100%); padding: 36px 40px; text-align: center; }
            .header h1 { color: white; font-size: 22px; font-weight: 700; letter-spacing: -0.3px; }
            .header p { color: rgba(255,255,255,0.8); font-size: 14px; margin-top: 6px; }
            .body { padding: 36px 40px; }
            .body p { font-size: 15px; line-height: 1.7; color: #374151; margin-bottom: 16px; }
            .body strong { color: #1e293b; }
            .highlight-box { background: #f0f7ff; border-left: 4px solid #2563eb; border-radius: 0 8px 8px 0; padding: 16px 20px; margin: 20px 0; }
            .highlight-box p { margin-bottom: 8px; font-size: 14px; }
            .highlight-box p:last-child { margin-bottom: 0; }
            .cta { text-align: center; margin: 28px 0; }
            .cta a { background: linear-gradient(135deg, #2563eb, #7c3aed); color: white; text-decoration: none; padding: 14px 32px; border-radius: 8px; font-size: 15px; font-weight: 600; display: inline-block; }
            .signature { margin-top: 28px; padding-top: 20px; border-top: 1px solid #e5e7eb; }
            .signature p { font-size: 14px; color: #6b7280; line-height: 1.6; }
            .signature strong { color: #1e293b; }
            .footer { background: #f8fafc; padding: 16px 40px; text-align: center; }
            .footer p { font-size: 11px; color: #9ca3af; }
            .footer a { color: #9ca3af; }
          </style>
        </head>
        <body>
          <div class="wrapper">
            <div class="header">
              <h1>#{subject}</h1>
            </div>
            <div class="body">
              <p>Bonjour,</p>
              <p>Je me permets de vous contacter au sujet de <strong>#{name_display}</strong>.</p>
              #{body_html}
              <div class="cta">
                <a href="mailto:remyfinot.pro@gmail.com?subject=Réponse - #{subject}">📩 Répondre à ce message</a>
              </div>
              <div class="signature">
                <p>Bien cordialement,<br>
                <strong>Remy Finot</strong><br>
                <a href="mailto:remyfinot.pro@gmail.com">remyfinot.pro@gmail.com</a></p>
              </div>
            </div>
            <div class="footer">
              <p>Vous recevez cet email car votre établissement figure dans l'annuaire public.
              <a href="#{unsubscribe_url}">Se désinscrire</a></p>
            </div>
          </div>
        </body>
        </html>
      HTML

      { subject: subject, html: html }
    end

    BODY_BY_CATEGORY = {
      town_hall: <<~HTML,
        <div class="highlight-box">
          <p>✅ <strong>Site web moderne</strong> — Informations claires, actualités et services en ligne</p>
          <p>✅ <strong>Espace citoyen</strong> — Formulaires dématérialisés, réduction des files d'attente</p>
          <p>✅ <strong>Accessibilité numérique</strong> — Conforme aux obligations légales (RGAA)</p>
        </div>
        <p>Ces outils permettent de réduire les démarches en mairie et d'améliorer le service aux administrés, souvent avec un budget très limité.</p>
        <p>Seriez-vous disponible pour un échange rapide cette semaine ?</p>
      HTML
      school: <<~HTML,
        <div class="highlight-box">
          <p>✅ <strong>Portail parents</strong> — Informations, absences et bulletins accessibles en ligne</p>
          <p>✅ <strong>Communication simplifiée</strong> — Notifications, newsletters et messagerie interne</p>
          <p>✅ <strong>Outils pédagogiques</strong> — Ressources partagées et agenda collaboratif</p>
        </div>
        <p>L'objectif est de renforcer le lien entre l'école et les familles tout en allégeant la charge administrative de vos équipes.</p>
        <p>Je serais ravi d'échanger sur vos besoins spécifiques — une courte présentation de 15 minutes suffit !</p>
      HTML
      medical: <<~HTML,
        <div class="highlight-box">
          <p>✅ <strong>Site professionnel</strong> — Présentation de vos spécialités et horaires à jour</p>
          <p>✅ <strong>Prise de rendez-vous en ligne</strong> — Moins d'appels, plus de disponibilités</p>
          <p>✅ <strong>Fiche Google optimisée</strong> — Visibilité locale immédiate sur Google Maps</p>
        </div>
        <p>Ces solutions permettent d'attirer de nouveaux patients qualifiés et de réduire la charge administrative à l'accueil.</p>
        <p>Serait-il possible d'en discuter brièvement cette semaine ?</p>
      HTML
      b2b: <<~HTML,
        <div class="highlight-box">
          <p>✅ <strong>Site vitrine professionnel</strong> — Image soignée et crédibilité renforcée</p>
          <p>✅ <strong>Référencement local (SEO)</strong> — Visible sur Google quand vos prospects cherchent</p>
          <p>✅ <strong>Présence Google Maps</strong> — Avis clients, horaires et contact en un clic</p>
        </div>
        <p>Ces outils permettent d'attirer de nouveaux clients qualifiés dans votre secteur sans dépendre uniquement du bouche-à-oreille.</p>
        <p>Je suis disponible pour un échange rapide si vous souhaitez en savoir plus.</p>
      HTML
      association: <<~HTML,
        <div class="highlight-box">
          <p>✅ <strong>Site web attractif</strong> — Présentez vos activités et recrutez des bénévoles</p>
          <p>✅ <strong>Gestion des adhésions</strong> — Inscriptions et paiements simplifiés en ligne</p>
          <p>✅ <strong>Communication digitale</strong> — Newsletter et réseaux sociaux pour grandir</p>
        </div>
        <p>L'objectif est de développer votre audience et de faciliter les financements participatifs ou les demandes de subventions.</p>
        <p>Je serais heureux d'en discuter autour d'un échange de 15 minutes.</p>
      HTML
      accommodation: <<~HTML,
        <div class="highlight-box">
          <p>✅ <strong>Réservation directe</strong> — Votre propre moteur de réservation, sans commission</p>
          <p>✅ <strong>Référencement local</strong> — Visible sur Google avant Booking et Airbnb</p>
          <p>✅ <strong>Fidélisation clients</strong> — Email marketing pour les clients récurrents</p>
        </div>
        <p>Réduire la dépendance aux plateformes comme Booking ou Airbnb peut représenter plusieurs milliers d'euros d'économies en commissions chaque année.</p>
        <p>Seriez-vous partant(e) pour en discuter rapidement ?</p>
      HTML
      coach: <<~HTML,
        <div class="highlight-box">
          <p>✅ <strong>Site vitrine</strong> — Vos services, témoignages clients et tarifs mis en valeur</p>
          <p>✅ <strong>Prise de rendez-vous en ligne</strong> — Agenda synchronisé et paiement en ligne</p>
          <p>✅ <strong>Visibilité locale</strong> — Apparaissez dans les recherches Google de votre ville</p>
        </div>
        <p>Ces outils permettent d'attirer des clients qui vous cherchent sur Google et de professionnaliser votre image.</p>
        <p>Je serais ravi d'échanger quelques minutes sur vos objectifs.</p>
      HTML
      restaurant: <<~HTML,
        <div class="highlight-box">
          <p>✅ <strong>Menu en ligne</strong> — QR code, mise à jour instantanée et click & collect</p>
          <p>✅ <strong>Réservation de table en ligne</strong> — Moins de no-show, plus de couverts assurés</p>
          <p>✅ <strong>Référencement Google</strong> — Apparaissez en tête des recherches "restaurant + ville"</p>
        </div>
        <p>Un client qui vous trouve sur Google Maps avec de beaux avis et un menu à jour, c'est une table de plus chaque soir. Je propose des solutions simples et accessibles pour les restaurateurs.</p>
        <p>Seriez-vous disponible pour un échange cette semaine ?</p>
      HTML
    }.freeze
  end
end
