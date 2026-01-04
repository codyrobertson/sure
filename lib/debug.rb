# Debug utility for easy error inspection in Rails console
#
# Usage in console:
#   Debug.chats          # Show recent chat errors
#   Debug.jobs           # Show recent failed jobs
#   Debug.logs(100)      # Show recent log lines
#   Debug.health         # Overall system health check
#
module Debug
  class << self
    # ============================================
    # CHAT DEBUGGING
    # ============================================

    # Show all chats with errors
    def chats(limit = 10)
      Chat.debug_errors
    end

    # Get a specific chat for inspection
    def chat(id)
      Chat.find(id)
    rescue ActiveRecord::RecordNotFound
      puts "Chat not found: #{id}"
      nil
    end

    # Clear all chat errors
    def clear_chat_errors!
      Chat.clear_all_errors!
    end

    # Clear all stale response IDs
    def clear_response_ids!
      Chat.clear_all_response_ids!
    end

    # ============================================
    # JOB DEBUGGING (Sidekiq)
    # ============================================

    # Show recent failed jobs
    def jobs(limit = 10)
      require "sidekiq/api"

      dead = Sidekiq::DeadSet.new
      retries = Sidekiq::RetrySet.new

      puts "=" * 70
      puts "SIDEKIQ JOB STATUS"
      puts "=" * 70
      puts "Dead jobs: #{dead.size}"
      puts "Retry queue: #{retries.size}"
      puts "-" * 70

      if dead.size > 0
        puts "\nRECENT DEAD JOBS:"
        dead.first(limit).each do |job|
          puts "\n  #{job.display_class}"
          puts "    Error: #{job.item['error_message']&.first(100)}"
          puts "    Failed at: #{Time.at(job.item['failed_at'])}" if job.item["failed_at"]
          puts "    Args: #{job.item['args'].inspect.first(80)}"
        end
      end

      if retries.size > 0
        puts "\nRETRY QUEUE:"
        retries.first(limit).each do |job|
          puts "\n  #{job.display_class}"
          puts "    Error: #{job.item['error_message']&.first(100)}"
          puts "    Retry count: #{job.item['retry_count']}"
        end
      end

      puts "=" * 70
      nil
    rescue LoadError
      puts "Sidekiq not available"
      nil
    end

    # Clear all dead jobs
    def clear_dead_jobs!
      require "sidekiq/api"
      dead = Sidekiq::DeadSet.new
      count = dead.size
      dead.clear
      puts "Cleared #{count} dead jobs"
      count
    rescue LoadError
      puts "Sidekiq not available"
      nil
    end

    # Retry all dead jobs
    def retry_dead_jobs!
      require "sidekiq/api"
      dead = Sidekiq::DeadSet.new
      count = 0
      dead.each do |job|
        job.retry
        count += 1
      end
      puts "Retried #{count} dead jobs"
      count
    rescue LoadError
      puts "Sidekiq not available"
      nil
    end

    # ============================================
    # RULE DEBUGGING
    # ============================================

    # Show rules with potential issues
    def rules
      puts "=" * 70
      puts "RULE DIAGNOSTICS"
      puts "=" * 70

      # Find rules referencing deleted categories
      orphaned_category_actions = Rule::Action.where(action_type: "set_transaction_category")
        .select { |a| a.value.present? && !Category.exists?(a.value) }

      if orphaned_category_actions.any?
        puts "\nRules with deleted categories:"
        orphaned_category_actions.each do |action|
          puts "  Rule ID: #{action.rule_id}, Action value: #{action.value}"
        end
      else
        puts "\nNo orphaned category references found"
      end

      # Find rules referencing deleted tags
      orphaned_tag_actions = Rule::Action.where(action_type: "set_transaction_tags")
        .select { |a| a.value.present? && !Tag.exists?(a.value) }

      if orphaned_tag_actions.any?
        puts "\nRules with deleted tags:"
        orphaned_tag_actions.each do |action|
          puts "  Rule ID: #{action.rule_id}, Action value: #{action.value}"
        end
      else
        puts "No orphaned tag references found"
      end

      puts "=" * 70
      nil
    end

    # ============================================
    # SYSTEM HEALTH
    # ============================================

    def health
      puts "=" * 70
      puts "SYSTEM HEALTH CHECK"
      puts "=" * 70

      # Database
      begin
        ActiveRecord::Base.connection.execute("SELECT 1")
        puts "✓ Database: Connected"
      rescue => e
        puts "✗ Database: #{e.message}"
      end

      # Redis/Sidekiq
      begin
        require "sidekiq/api"
        Sidekiq.redis { |conn| conn.ping }
        stats = Sidekiq::Stats.new
        puts "✓ Redis: Connected"
        puts "  - Processed: #{stats.processed}"
        puts "  - Failed: #{stats.failed}"
        puts "  - Enqueued: #{stats.enqueued}"
      rescue => e
        puts "✗ Redis/Sidekiq: #{e.message}"
      end

      # Chat errors
      chat_errors = Chat.with_errors.count
      if chat_errors > 0
        puts "⚠ Chat errors: #{chat_errors} chats have errors"
      else
        puts "✓ Chat errors: None"
      end

      # Stale response IDs
      stale_ids = Chat.with_response_ids.count
      if stale_ids > 0
        puts "⚠ Stale response IDs: #{stale_ids} chats have response IDs"
      else
        puts "✓ Stale response IDs: None"
      end

      puts "=" * 70
      nil
    end

    # ============================================
    # HELPERS
    # ============================================

    # Quick summary of everything
    def all
      health
      puts "\n"
      chats
      puts "\n"
      jobs
      puts "\n"
      rules
    end

    # Help text
    def help
      puts <<~HELP
        Debug Utility - Quick Reference
        ================================

        CHAT DEBUGGING:
          Debug.chats              # Show recent chat errors
          Debug.chat(id)           # Get specific chat for inspection
          Debug.clear_chat_errors! # Clear all chat errors
          Debug.clear_response_ids!# Clear stale response IDs

        JOB DEBUGGING:
          Debug.jobs               # Show failed Sidekiq jobs
          Debug.clear_dead_jobs!   # Clear all dead jobs
          Debug.retry_dead_jobs!   # Retry all dead jobs

        RULE DEBUGGING:
          Debug.rules              # Check for orphaned rule references

        SYSTEM:
          Debug.health             # Overall system health check
          Debug.all                # Run all diagnostics
          Debug.help               # Show this help

        INDIVIDUAL CHAT METHODS:
          chat.inspect_error       # Print detailed error info
          chat.error_details       # Get error as hash
          chat.error_summary       # One-line error summary
          chat.debug_info          # Full debug info hash
      HELP
      nil
    end
  end
end
