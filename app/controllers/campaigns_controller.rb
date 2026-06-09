class CampaignsController < ApplicationController
  def index
    @stats = {}
    Organization.categories.each_key do |cat|
      @stats[cat] = {
        total:         Organization.send(cat).count,
        with_email:    Organization.send(cat).with_email.count,
        ready:         Organization.send(cat).ready_to_contact.count,
        already_sent:  Organization.send(cat).where.not(email_sent_at: nil).count,
      }
    end
    @global_ready = Organization.ready_to_contact.count
    @global_sent  = Organization.where.not(email_sent_at: nil).count
  end

  def send_campaign
    category = params[:category].presence
    limit    = (params[:limit] || 50).to_i
    
    SendEmailCampaignJob.perform_later(category: category, limit: limit)
    redirect_to campaigns_path, notice: "Campagne lancée ! Envoi de #{limit} emails#{category ? " (#{category})" : ""} en cours en arrière-plan."
  end

  def preview
    category = params[:category] || 'town_hall'
    org = Organization.send(category).with_email.first

    # Si pas de contact réel pour cette catégorie, on utilise un contact fictif
    # pour quand même afficher le bon template
    unless org
      org = Organization.new(
        name:     "Exemple #{category.humanize}",
        category: category,
        email:    "exemple@organisation.fr",
        city:     "Paris"
      )
    end

    template = Mailers::Templates.build(org)
    render html: template[:html].html_safe
  end
  def unsubscribe
    org = Organization.find_by(id: params[:id])
    if org
      org.update_column(:unsubscribed_at, Time.current)
      render plain: "Vous avez été désinscrit(e) avec succès. Vous ne recevrez plus d'emails de notre part."
    else
      render plain: "Lien invalide.", status: :not_found
    end
  end
end
