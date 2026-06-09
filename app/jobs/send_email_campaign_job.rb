class SendEmailCampaignJob < ApplicationJob
  queue_as :default

  def perform(category: nil, limit: 100)
    scope = Organization.ready_to_contact
    scope = scope.where(category: Organization.categories[category]) if category.present?
    
    orgs = scope.order(created_at: :asc).limit(limit)
    puts "-> Sending emails to #{orgs.count} organizations (category: #{category || 'all'})..."

    sent = 0
    failed = 0

    orgs.each do |org|
      begin
        template = Mailers::Templates.build(org)
        result   = Mailers::BrevoService.send_email(
          to_email:     org.email,
          to_name:      org.name,
          subject:      template[:subject],
          html_content: template[:html]
        )

        if result[:success]
          org.update_column(:email_sent_at, Time.current)
          puts "   ✓ Sent to #{org.name} <#{org.email}>"
          sent += 1
        else
          puts "   ✗ Failed for #{org.name}: #{result[:error]}"
          failed += 1
        end

        # Respecter la limite d'envoi Brevo : ~14/min pour rester bien en dessous de 300/jour
        sleep 4

      rescue => e
        puts "   ✗ Exception for #{org.name}: #{e.message}"
        failed += 1
      end
    end

    puts "-> Campaign done: #{sent} sent, #{failed} failed."
  end
end
