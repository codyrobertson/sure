class Provider::Exa < Provider
  Error = Class.new(Provider::Error)

  SearchResult = Data.define(:title, :url, :published_date, :author, :text, :highlights, :summary, :score)

  def initialize(api_key)
    @api_key = api_key
  end

  def self.configured?
    api_key.present?
  end

  def self.api_key
    ENV["EXA_API_KEY"]
  end

  def healthy?
    with_provider_response do
      # Simple search to verify API key works
      response = client.post("#{base_url}/search") do |req|
        req.body = { query: "test", numResults: 1 }.to_json
      end
      JSON.parse(response.body).key?("results")
    end
  end

  # Main search method
  # @param query [String] The search query
  # @param options [Hash] Additional options:
  #   - num_results [Integer] Number of results (default: 5, max: 10 for assistant use)
  #   - category [String] Focus category: company, research_paper, news, pdf, github, tweet
  #   - include_domains [Array<String>] Restrict to these domains
  #   - exclude_domains [Array<String>] Exclude these domains
  #   - start_published_date [String] Filter by publish date (YYYY-MM-DD)
  #   - text [Boolean] Include full text content (default: false)
  #   - highlights [Boolean] Include key highlights (default: true)
  #   - summary [Boolean] Include AI summary (default: true)
  def search(query, **options)
    with_provider_response do
      body = build_search_body(query, options)

      response = client.post("#{base_url}/search") do |req|
        req.body = body.to_json
      end

      parsed = JSON.parse(response.body)

      if parsed["error"]
        raise Error, parsed["error"]
      end

      parsed["results"].map do |result|
        SearchResult.new(
          title: result["title"],
          url: result["url"],
          published_date: result["publishedDate"],
          author: result["author"],
          text: result["text"],
          highlights: result["highlights"],
          summary: result["summary"],
          score: result["score"]
        )
      end
    end
  end

  private
    attr_reader :api_key

    def base_url
      ENV["EXA_API_URL"] || "https://api.exa.ai"
    end

    def client
      @client ||= Faraday.new(url: base_url) do |faraday|
        faraday.request(:retry, {
          max: 2,
          interval: 0.1,
          interval_randomness: 0.5,
          backoff_factor: 2
        })

        faraday.request :json
        faraday.response :raise_error
        faraday.headers["x-api-key"] = api_key
        faraday.headers["Content-Type"] = "application/json"
      end
    end

    def build_search_body(query, options)
      body = {
        query: query,
        numResults: [ options.fetch(:num_results, 5), 10 ].min, # Cap at 10 for cost control
        type: options.fetch(:type, "auto")
      }

      # Content options
      contents = {}
      contents[:text] = true if options[:text]
      contents[:highlights] = { numSentences: 3 } if options.fetch(:highlights, true)
      contents[:summary] = { query: query } if options.fetch(:summary, true)

      body[:contents] = contents if contents.present?

      # Category filter
      body[:category] = options[:category] if options[:category].present?

      # Domain filters
      body[:includeDomains] = options[:include_domains] if options[:include_domains].present?
      body[:excludeDomains] = options[:exclude_domains] if options[:exclude_domains].present?

      # Date filters
      body[:startPublishedDate] = options[:start_published_date] if options[:start_published_date].present?
      body[:endPublishedDate] = options[:end_published_date] if options[:end_published_date].present?

      body
    end
end
