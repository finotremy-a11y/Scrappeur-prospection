require "test_helper"

class WebsiteAnalyzerTest < ActiveSupport::TestCase
  FakeResponse = Struct.new(:code, :body)

  test "returns a result for an empty URL or invalid text" do
    [ nil, "", "pas de site web" ].each do |url|
      result = WebsiteAnalyzer.new(url).analyze

      assert_nil result.http_status
      assert result.error.present?
      assert_equal 0, WebsiteAnalyzer.score(result)
    end
  end

  test "keeps the SSL pain-point score when certificate validation fails" do
    analyzer = WebsiteAnalyzer.new("https://example.test")
    analyzer.define_singleton_method(:fetch) { raise OpenSSL::SSL::SSLError, "certificate verify failed" }

    result = analyzer.analyze

    assert_equal 2, WebsiteAnalyzer.score(result)
  end

  test "converts SSL, DNS, refused connection and timeout failures into results" do
    failures = [
      OpenSSL::SSL::SSLError.new("certificate verify failed"),
      SocketError.new("getaddrinfo: Name or service not known"),
      Errno::ECONNREFUSED.new,
      Net::ReadTimeout.new("execution expired"),
      Timeout::Error.new("execution expired")
    ]

    failures.each do |failure|
      analyzer = WebsiteAnalyzer.new("https://example.test")
      analyzer.define_singleton_method(:fetch) { raise failure }
      result = analyzer.analyze

      assert_nil result.http_status
      assert_includes result.error, failure.class.name
    end
  end

  test "does not fail when a successful response has empty or malformed HTML" do
    [ "", "<html><body><div" ].each do |html|
      analyzer = WebsiteAnalyzer.new("http://example.test")
      analyzer.define_singleton_method(:fetch) do
        [ FakeResponse.new("200", html), URI.parse("http://example.test"), 0.001 ]
      end

      result = analyzer.analyze

      assert_equal 200, result.http_status
      assert_equal false, result.has_form
      if html.empty?
        assert_nil result.cms_detected
      else
        assert_equal WebsiteAnalyzer::UNKNOWN_CMS, result.cms_detected
      end
    end
  end

  test "normalizes detected CMS" do
    {
      '<link href="/wp-content/plugins/elementor/a.css">' => "WordPress (Elementor)",
      '<link href="/wp-content/themes/Divi/a.css">' => "WordPress (Divi)",
      '<div class="et-builder"></div><script src="/wp-includes/x.js">' => "WordPress (Divi)",
      '<script src="/wp-includes/x.js"></script>' => "WordPress",
      "<script>var _PS_VERSION_ = 1;</script>" => "PrestaShop",
      '<script src="https://cdn.shopify.com/s.js"></script>' => "Shopify",
      '<script src="https://static.parastorage.com/wix.com/a.js"></script>' => "Wix",
      '<link href="https://x.wixsite.com/a">' => "Wix",
      '<meta name="x" content="https://www.wix.com/y">' => "Wix",
      '</head><body><a href="https://wix.com">Wix</a><p>Webflow vs wix.com</p>' => WebsiteAnalyzer::UNKNOWN_CMS,
      '<html data-wf-site="1"><link href="webflow.css">' => "Webflow",
      '<meta name="Generator" content="Joomla! - Open Source">' => "Joomla",
      '<meta name="generator" content="Drupal 10 (https://www.drupal.org)">' => "Drupal",
      "<p>Bonjour</p>" => WebsiteAnalyzer::UNKNOWN_CMS
    }.each do |html, expected|
      analyzer = WebsiteAnalyzer.new("https://example.test")
      analyzer.define_singleton_method(:fetch) do
        [ FakeResponse.new("200", "<html><head>#{html}</head></html>"), URI.parse("https://example.test"), 0.001 ]
      end

      assert_equal expected, analyzer.analyze.cms_detected, html
    end
  end

  test "valid_url? requires http(s) scheme and a real domain" do
    assert WebsiteAnalyzer.valid_url?("https://example.com/path")
    assert WebsiteAnalyzer.valid_url?("http://sub.example.fr")
    [ nil, "", "pas de site web", "example.com", "ftp://example.com", "https://", "http://localhost", "https://exa mple.com" ].each do |value|
      assert_not WebsiteAnalyzer.valid_url?(value), value.inspect
    end
  end
end
