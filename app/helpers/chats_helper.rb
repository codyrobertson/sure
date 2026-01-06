module ChatsHelper
  def chat_frame
    :sidebar_chat
  end

  def chat_view_path(chat, page_context: nil, metadata: nil)
    base_path = if params[:chat_view] == "new"
      new_chat_path
    elsif chat.nil? || params[:chat_view] == "all"
      chats_path
    else
      chat.persisted? ? chat_path(chat) : new_chat_path
    end

    # Add page context params if provided
    query_params = {}
    query_params[:page_context] = page_context if page_context.present?
    query_params[:metadata] = metadata.to_json if metadata.present?

    return base_path if query_params.empty?

    uri = URI(base_path)
    uri.query = query_params.to_query
    uri.to_s
  end

  # Convenience method to get chat path with current page context
  def chat_view_path_with_context(chat)
    chat_view_path(
      chat,
      page_context: current_page_context_key,
      metadata: current_page_metadata
    )
  end

  def smart_chat_suggestions(family)
    # Get AI-generated suggestions (cached for 24h)
    # Returns pool of ~10 suggestions, we randomly pick 3
    all_suggestions = Chat::SuggestionGenerator.new(family).suggestions
    all_suggestions.shuffle.first(3)
  rescue => e
    Rails.logger.error("Failed to get chat suggestions: #{e.message}")
    fallback_suggestions.shuffle.first(3)
  end

  private

  def fallback_suggestions
    [
      { icon: "pie-chart", text: "Show my spending breakdown" },
      { icon: "trending-up", text: "How is my net worth trending?" },
      { icon: "repeat", text: "What are my recurring expenses?" },
      { icon: "sparkles", text: "Give me a financial health checkup" },
      { icon: "tag", text: "Help me categorize transactions" }
    ]
  end
end
