class Assistant::Function::FindRelatedTransactions < Assistant::Function
  class << self
    def name
      "find_related_transactions"
    end

    def description
      <<~INSTRUCTIONS
        Use this to find transactions that occur near other transactions in time.
        Useful for identifying patterns like paired payments and funding sources, refunds near purchases, or recurring transaction pairs.

        IMPORTANT - USE SEARCH, NOT ACCOUNTS:
        External transfers (Coinbase, Robinhood, Venmo, etc.) usually appear on BANK accounts
        with the service name in the transaction description. Use related_search to find them
        by name, NOT related_accounts.

        EXAMPLE - Find Coinbase deposits near Amex payments:
        ```
        find_related_transactions({
          reference_search: "american express",
          reference_types: ["expense"],
          related_search: "coinbase",
          related_types: ["income"],
          temporal_relation: "same_day"
        })
        ```

        SEARCH TIPS:
        - Search is case-insensitive SUBSTRING match on transaction names
        - Common abbreviations are auto-expanded:
          "amex" → also searches "american express"
          "rh" → also searches "robinhood"
          "cb" → also searches "coinbase"
          "bofa"/"boa" → also searches "bank of america"
        - Don't add extra words like "payment" or "transfer" - just the key identifier

        TYPE CLASSIFICATION:
        - "income" = money coming IN (deposits, transfers in, refunds, external transfers into bank)
        - "expense" = money going OUT (payments, purchases)
        - "transfer" = ONLY internal transfers explicitly marked as funds_movement/cc_payment

        For external transfers coming INTO an account, use types: ["income"], NOT ["transfer"].

        Parameters:
        - reference_* params define the "anchor" transactions to match against
        - related_* params define what to find near those anchors
        - temporal_relation: "same_day", "within_days", "before", "after"
        - days_window: number of days for temporal matching (default 1)

        AUTO-TAGGING:
        You can automatically tag all matched transactions by providing tag_matches:
        ```
        find_related_transactions({
          reference_search: "american express",
          reference_types: ["expense"],
          related_search: "coinbase",
          related_types: ["income"],
          temporal_relation: "same_day",
          tag_matches: "CC Funding"
        })
        ```
        This creates the tag if needed and applies it to BOTH reference and related transactions.
      INSTRUCTIONS
    end
  end

  def params_schema
    build_schema(
      required: ["temporal_relation"],
      properties: {
        # Reference transaction criteria (the "anchor" transactions)
        reference_search: {
          type: "string",
          description: "Search term to find reference transactions (by name/merchant)"
        },
        reference_types: {
          type: "array",
          description: "Filter reference transactions by type: 'income', 'expense', or 'transfer'",
          items: { enum: %w[income expense transfer] }
        },
        reference_merchants: {
          type: "array",
          description: "Filter reference transactions by merchant names",
          items: { type: "string" }
        },
        reference_categories: {
          type: "array",
          description: "Filter reference transactions by category names",
          items: { type: "string" }
        },
        reference_accounts: {
          type: "array",
          description: "Filter reference transactions by account names",
          items: { type: "string" }
        },
        reference_min_amount: {
          type: "number",
          description: "Minimum amount for reference transactions"
        },
        reference_max_amount: {
          type: "number",
          description: "Maximum amount for reference transactions"
        },
        # Related transaction criteria (what we're looking for near reference transactions)
        related_search: {
          type: "string",
          description: "Search term to find related transactions (by name/merchant)"
        },
        related_types: {
          type: "array",
          description: "Filter related transactions by type: 'income', 'expense', or 'transfer'",
          items: { enum: %w[income expense transfer] }
        },
        related_merchants: {
          type: "array",
          description: "Filter related transactions by merchant names",
          items: { type: "string" }
        },
        related_categories: {
          type: "array",
          description: "Filter related transactions by category names",
          items: { type: "string" }
        },
        related_accounts: {
          type: "array",
          description: "Filter related transactions by account names",
          items: { type: "string" }
        },
        related_min_amount: {
          type: "number",
          description: "Minimum amount for related transactions"
        },
        related_max_amount: {
          type: "number",
          description: "Maximum amount for related transactions"
        },
        # Temporal relationship
        temporal_relation: {
          type: "string",
          description: "How the related transactions should relate in time to reference transactions",
          enum: %w[same_day within_days before after]
        },
        days_window: {
          type: "integer",
          description: "Number of days for 'within_days' relation (default: 1)"
        },
        # Date range to search within
        start_date: {
          type: "string",
          description: "Only search transactions on or after this date (YYYY-MM-DD)"
        },
        end_date: {
          type: "string",
          description: "Only search transactions on or before this date (YYYY-MM-DD)"
        },
        # Auto-tagging
        tag_matches: {
          type: "string",
          description: "Tag name to apply to all matched transactions (both reference and related). Creates the tag if it doesn't exist."
        }
      }
    )
  end

  MAX_REFERENCE_TRANSACTIONS = 100
  MAX_RESULTS = 500

  def call(params = {})
    Rails.logger.info "[FindRelatedTransactions] Called with params: #{params.inspect}"
    report_progress("Finding reference transactions...")

    # Build reference transaction filters (date range applies to reference only)
    reference_filters = build_filters(params, "reference")
    reference_filters["start_date"] = params["start_date"] if params["start_date"].present?
    reference_filters["end_date"] = params["end_date"] if params["end_date"].present?
    Rails.logger.info "[FindRelatedTransactions] Reference filters: #{reference_filters.inspect}"

    reference_scope = Transaction::Search.new(family, filters: reference_filters).transactions_scope
    reference_scope = apply_search_filter(reference_scope, params["reference_search"])
    reference_scope = apply_amount_filters(reference_scope, params, "reference")

    # Order by date descending to get most recent first
    reference_transactions = reference_scope
      .joins(:entry)
      .order("entries.date DESC")
      .includes(entry: :account)
      .limit(MAX_REFERENCE_TRANSACTIONS)
      .to_a

    Rails.logger.info "[FindRelatedTransactions] Found #{reference_transactions.size} reference transactions"
    reference_transactions.each do |txn|
      Rails.logger.info "[FindRelatedTransactions] Reference: #{txn.entry.date} - #{txn.entry.name} - #{txn.entry.amount}"
    end

    if reference_transactions.empty?
      return { error: "No reference transactions found matching criteria" }
    end

    report_progress("Found #{reference_transactions.size} reference transactions, searching for related...")

    # Build related transaction filters (NO date range - temporal matching handles dates)
    related_filters = build_filters(params, "related")
    Rails.logger.info "[FindRelatedTransactions] Related filters: #{related_filters.inspect}"
    # Don't apply start_date/end_date to related - we want to find matches based on temporal relation

    temporal_relation = params["temporal_relation"]
    days_window = (params["days_window"] || 1).to_i
    Rails.logger.info "[FindRelatedTransactions] Temporal: #{temporal_relation}, days_window: #{days_window}"

    matches = []
    reference_transactions.each do |ref_txn|
      ref_date = ref_txn.entry.date

      date_range = case temporal_relation
      when "same_day"
        ref_date..ref_date
      when "within_days"
        (ref_date - days_window.days)..(ref_date + days_window.days)
      when "before"
        (ref_date - days_window.days)...ref_date
      when "after"
        (ref_date + 1.day)..(ref_date + days_window.days)
      end

      # Build fresh query for each reference to avoid scope pollution
      related_scope = Transaction::Search.new(family, filters: related_filters).transactions_scope
      related_scope = apply_search_filter(related_scope, params["related_search"])
      related_scope = apply_amount_filters(related_scope, params, "related")

      related = related_scope
        .joins(:entry)
        .where(entries: { date: date_range })
        .where.not(id: ref_txn.id)
        .includes(entry: :account)
        .limit(20)
        .to_a

      Rails.logger.info "[FindRelatedTransactions] Ref #{ref_date} (#{ref_txn.entry.name}): found #{related.size} related in range #{date_range}"

      related.each do |rel_txn|
        matches << {
          reference_transaction: format_transaction(ref_txn),
          related_transaction: format_transaction(rel_txn),
          days_apart: (rel_txn.entry.date - ref_date).to_i.abs
        }
      end

      break if matches.size >= MAX_RESULTS
    end

    if matches.empty?
      return {
        message: "No related transactions found matching the temporal criteria",
        reference_count: reference_transactions.size,
        suggestion: "Try adjusting the related transaction filters or increasing the days_window"
      }
    end

    # Deduplicate - same related transaction may match multiple references
    unique_related_ids = matches.map { |m| m[:related_transaction][:id] }.uniq
    unique_reference_ids = matches.map { |m| m[:reference_transaction][:id] }.uniq

    result = {
      matches: matches.first(100),
      total_matches: matches.size,
      unique_related_transaction_ids: unique_related_ids,
      unique_reference_transaction_ids: unique_reference_ids,
      unique_related_count: unique_related_ids.size,
      unique_reference_count: unique_reference_ids.size
    }

    # Auto-tag matches if requested
    if params["tag_matches"].present?
      tag = family.tags.find_or_create_by!(name: params["tag_matches"])
      all_txn_ids = (unique_reference_ids + unique_related_ids).uniq
      tagged_count = 0

      Transaction.where(id: all_txn_ids).find_each do |txn|
        unless txn.tags.include?(tag)
          txn.tags << tag
          tagged_count += 1
        end
      end

      result[:tag_applied] = tag.name
      result[:tagged_count] = tagged_count
      result[:already_tagged] = all_txn_ids.size - tagged_count
    else
      result[:tip] = "Use tag_transactions with transaction_ids to label these transactions"
    end

    result
  end

  private

  def build_filters(params, prefix)
    filters = {}
    # Don't pass search to Transaction::Search - we'll handle it with ILIKE for better matching
    filters["types"] = params["#{prefix}_types"] if params["#{prefix}_types"].present?
    filters["merchants"] = params["#{prefix}_merchants"] if params["#{prefix}_merchants"].present?
    filters["categories"] = params["#{prefix}_categories"] if params["#{prefix}_categories"].present?
    filters["accounts"] = params["#{prefix}_accounts"] if params["#{prefix}_accounts"].present?
    filters
  end

  # Common abbreviations mapped to their full names
  ABBREVIATION_EXPANSIONS = {
    "amex" => "american express",
    "rh" => "robinhood",
    "cb" => "coinbase",
    "bofa" => "bank of america",
    "citi" => "citibank",
    "chase" => "jpmorgan chase",
    "cap one" => "capital one",
    "venmo" => "venmo",
    "zelle" => "zelle",
    "boa" => "bank of america"
  }.freeze

  # More lenient search using ILIKE on entry name with abbreviation expansion
  def apply_search_filter(scope, search_term)
    return scope if search_term.blank?

    search_terms = [search_term.downcase]

    # Expand abbreviations to include full names
    ABBREVIATION_EXPANSIONS.each do |abbrev, full_name|
      if search_term.downcase.include?(abbrev)
        search_terms << full_name
      end
    end

    # Also check if the search term IS a full name that has an abbreviation
    ABBREVIATION_EXPANSIONS.each do |abbrev, full_name|
      if search_term.downcase.include?(full_name)
        search_terms << abbrev
      end
    end

    search_terms.uniq!

    if search_terms.size == 1
      sanitized = "%#{ActiveRecord::Base.sanitize_sql_like(search_terms.first)}%"
      scope.where("entries.name ILIKE ?", sanitized)
    else
      # Build OR conditions for multiple search terms
      conditions = search_terms.map do |term|
        sanitized = "%#{ActiveRecord::Base.sanitize_sql_like(term)}%"
        "entries.name ILIKE #{ActiveRecord::Base.connection.quote(sanitized)}"
      end
      scope.where(conditions.join(" OR "))
    end
  end

  def apply_amount_filters(scope, params, prefix)
    min_amount = params["#{prefix}_min_amount"]
    max_amount = params["#{prefix}_max_amount"]

    # Don't call joins(:entry) here - it will be called once when we execute the query
    if min_amount.present?
      scope = scope.where("ABS(entries.amount) >= ?", min_amount)
    end

    if max_amount.present?
      scope = scope.where("ABS(entries.amount) <= ?", max_amount)
    end

    scope
  end

  def format_transaction(txn)
    entry = txn.entry
    {
      id: txn.id,
      name: entry.name,
      date: entry.date,
      amount: entry.amount.abs,
      formatted_amount: entry.amount_money.abs.format,
      classification: entry.amount < 0 ? "income" : "expense",
      account: entry.account.name,
      category: txn.category&.name,
      merchant: txn.merchant&.name
    }
  end
end
