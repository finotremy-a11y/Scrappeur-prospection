module Mailers
  class BrevoService
    include HTTParty
    base_uri 'https://api.brevo.com/v3'

    SENDER_EMAIL = ENV.fetch('BREVO_SENDER_EMAIL', 'remyfinot.pro@gmail.com')
    SENDER_NAME  = ENV.fetch('BREVO_SENDER_NAME', 'Remy Finot')
    API_KEY      = ENV.fetch('BREVO_API_KEY', '')

    def self.send_email(to_email:, to_name:, subject:, html_content:)
      return { error: "No API key configured" } if API_KEY.blank?

      headers = {
        'accept'       => 'application/json',
        'api-key'      => API_KEY,
        'content-type' => 'application/json'
      }

      body = {
        sender: { name: SENDER_NAME, email: SENDER_EMAIL },
        to:     [{ email: to_email, name: to_name.presence || to_email.split('@').first.titleize }],
        subject: subject,
        htmlContent: html_content
      }

      response = post('/smtp/email', headers: headers, body: body.to_json)

      if response.success?
        { success: true, message_id: response.parsed_response['messageId'] }
      else
        { success: false, error: response.parsed_response['message'] }
      end
    rescue => e
      { success: false, error: e.message }
    end

    # Test connectivity with Brevo API
    def self.test_connection
      headers = { 'accept' => 'application/json', 'api-key' => API_KEY }
      response = get('/account', headers: headers)
      response.success? ? { success: true, plan: response.parsed_response.dig('plan', 0, 'type') } : { success: false, error: response.parsed_response['message'] }
    rescue => e
      { success: false, error: e.message }
    end
  end
end
