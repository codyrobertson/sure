module ChatsHelper
  def chat_frame
    :sidebar_chat
  end

  def chat_view_path(chat)
    return new_chat_path if params[:chat_view] == "new"
    return chats_path if chat.nil? || params[:chat_view] == "all"

    chat.persisted? ? chat_path(chat) : new_chat_path
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
