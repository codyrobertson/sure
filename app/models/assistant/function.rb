class Assistant::Function
  class << self
    def name
      raise NotImplementedError, "Subclasses must implement the name class method"
    end

    def description
      raise NotImplementedError, "Subclasses must implement the description class method"
    end
  end

  def initialize(user)
    @user = user
    @progress_callback = nil
  end

  # Set a callback to receive progress updates during execution
  def on_progress(&block)
    @progress_callback = block
    self
  end

  def call(params = {})
    raise NotImplementedError, "Subclasses must implement the call method"
  end

  def name
    self.class.name
  end

  def description
    self.class.description
  end

  def params_schema
    build_schema
  end

  # (preferred) when in strict mode, the schema needs to include all properties in required array
  def strict_mode?
    true
  end

  def to_definition
    {
      name: name,
      description: description,
      params_schema: params_schema,
      strict: strict_mode?
    }
  end

  private
    attr_reader :user, :progress_callback

    def report_progress(message)
      progress_callback&.call(message)
    end

    # Broadcast a page refresh to all family members so UI updates in real-time
    # Call this after any write operation that modifies user data
    def broadcast_data_changed
      Turbo::StreamsChannel.broadcast_refresh_to(family)
    end

    def build_schema(properties: {}, required: [])
      {
        type: "object",
        properties: properties,
        required: required,
        additionalProperties: false
      }
    end

    def family_account_names
      @family_account_names ||= family.accounts.visible.pluck(:name)
    end

    def family_category_names
      @family_category_names ||= begin
        names = family.categories.pluck(:name)
        names << "Uncategorized"
        names
      end
    end

    def family_merchant_names
      @family_merchant_names ||= family.merchants.pluck(:name)
    end

    def family_tag_names
      @family_tag_names ||= family.tags.pluck(:name)
    end

    def family
      user.family
    end

    # To save tokens, we provide the AI metadata about the series and a flat array of
    # raw, formatted values which it can infer dates from
    def to_ai_time_series(series)
      {
        start_date: series.start_date,
        end_date: series.end_date,
        interval: series.interval,
        values: series.values.map { |v| v.trend.current.format }
      }
    end
end
