class Assistant::Function::WebSearch < Assistant::Function
  class << self
    def name
      "web_search"
    end

    def description
      <<~DESC
        Search the web for information using Exa AI search.
        Use this when the user asks about:
        - Financial concepts, strategies, or advice (e.g., "what is dollar cost averaging?")
        - Current events, news, or market information
        - Product comparisons or reviews
        - General knowledge questions you don't have data for
        - Research topics

        DO NOT use this for questions about the user's own financial data - use the other functions for that.
        Search results will be displayed as cards in the chat with source links.
      DESC
    end
  end

  def params_schema
    build_schema(
      properties: {
        query: {
          type: "string",
          description: "The search query - be specific and descriptive for best results"
        },
        category: {
          type: "string",
          enum: %w[company research_paper news github financial_report],
          description: "Optional: focus on specific content type"
        },
        num_results: {
          type: "integer",
          description: "Number of results to return (1-10, default: 5)"
        }
      },
      required: %w[query]
    )
  end

  def call(params = {})
    unless Provider::Exa.configured?
      return { error: "Web search is not configured. Please set EXA_API_KEY." }
    end

    query = params["query"]
    return { error: "Query is required" } if query.blank?

    report_progress("Searching the web...")

    exa = Provider::Exa.new(Provider::Exa.api_key)

    options = {
      num_results: [ params["num_results"] || 5, 10 ].min,
      highlights: true,
      summary: true
    }
    options[:category] = params["category"] if params["category"].present?

    response = exa.search(query, **options)

    unless response.success?
      return { error: "Search failed: #{response.error&.message || 'Unknown error'}" }
    end

    results = response.data.map do |result|
      {
        title: result.title,
        url: result.url,
        published_date: result.published_date,
        author: result.author,
        highlights: result.highlights&.first(3),
        summary: result.summary
      }
    end

    {
      query: query,
      results: results,
      result_count: results.length,
      search_type: "web_search",
      note: "Present these results to the user with source attribution. Cite sources when summarizing."
    }
  end
end
