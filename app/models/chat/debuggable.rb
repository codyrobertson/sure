module Chat::Debuggable
  extend ActiveSupport::Concern

  def debug_mode?
    ENV["AI_DEBUG_MODE"] == "true"
  end

  # Returns parsed error details in a readable format
  def error_details
    return nil unless error.present?

    parsed = if error.is_a?(String)
      begin
        JSON.parse(error)
      rescue JSON::ParserError
        { "raw" => error }
      end
    else
      error
    end
    {
      message: extract_error_message(parsed),
      class: parsed["class"] || parsed.class.name,
      backtrace: parsed["backtrace"]&.first(10),
      raw: parsed
    }
  end

  # Human-readable error summary for quick inspection
  def error_summary
    return "No error" unless error.present?

    details = error_details
    "#{details[:class]}: #{details[:message]}"
  end

  # Full debug info for the chat
  def debug_info
    {
      id: id,
      title: title,
      user_id: user_id,
      message_count: messages.count,
      last_message: messages.ordered.last&.slice(:type, :content, :ai_model, :created_at),
      latest_assistant_response_id: latest_assistant_response_id,
      error: error_details,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  # Print debug info to console (Rails console friendly)
  def inspect_error
    return puts "No error on this chat" unless error.present?

    details = error_details
    puts "=" * 60
    puts "CHAT ERROR: #{id}"
    puts "=" * 60
    puts "Title: #{title}"
    puts "User: #{user_id}"
    puts "-" * 60
    puts "Error Class: #{details[:class]}"
    puts "Error Message: #{details[:message]}"
    puts "-" * 60
    if details[:backtrace].present?
      puts "Backtrace (first 10 lines):"
      details[:backtrace].each { |line| puts "  #{line}" }
    end
    puts "=" * 60
    nil
  end

  private

  def extract_error_message(parsed)
    # Try various common error message locations
    parsed["message"] ||
      parsed["error"] ||
      parsed.dig("data", "message") ||
      parsed.dig("error", "message") ||
      parsed.to_s.first(200)
  end

  class_methods do
    # Find chats with errors
    def with_errors
      where.not(error: nil)
    end

    # Find chats with stale response IDs (potential 400 error sources)
    def with_response_ids
      where.not(latest_assistant_response_id: nil)
    end

    # Recent chats with errors
    def recent_errors(limit = 10)
      with_errors.order(updated_at: :desc).limit(limit)
    end

    # Print summary of all chats with errors
    def debug_errors
      chats = recent_errors
      return puts "No chats with errors found" if chats.empty?

      puts "=" * 70
      puts "CHATS WITH ERRORS (#{chats.count} found)"
      puts "=" * 70
      chats.each do |chat|
        puts "\n#{chat.id}"
        puts "  Title: #{chat.title.first(50)}"
        puts "  Error: #{chat.error_summary}"
        puts "  Updated: #{chat.updated_at}"
      end
      puts "=" * 70
      nil
    end

    # Clear all errors (use in console to reset)
    def clear_all_errors!
      count = with_errors.update_all(error: nil)
      puts "Cleared errors from #{count} chats"
      count
    end

    # Clear all stale response IDs
    def clear_all_response_ids!
      count = with_response_ids.update_all(latest_assistant_response_id: nil)
      puts "Cleared response IDs from #{count} chats"
      count
    end
  end
end
