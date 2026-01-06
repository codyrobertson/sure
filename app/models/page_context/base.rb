class PageContext::Base
  CACHE_TTL = 1.hour
  MAX_PROMPTS = 5

  attr_reader :family, :user, :metadata

  def initialize(family:, user:, metadata: {})
    @family = family
    @user = user
    @metadata = metadata.with_indifferent_access
  end

  # Main interface - returns array of prompt hashes
  def prompts
    cached_prompts = read_cache
    return cached_prompts if cached_prompts.present?

    generated = generate_prompts
    write_cache(generated)
    generated
  end

  # Override in subclasses
  def page_name
    raise NotImplementedError, "Subclasses must implement #page_name"
  end

  # Override in subclasses
  def page_icon
    raise NotImplementedError, "Subclasses must implement #page_icon"
  end

  # Can this context generate prompts? (has enough data)
  def available?
    true
  end

  private

    def generate_prompts
      raise NotImplementedError, "Subclasses must implement #generate_prompts"
    end

    def cache_key
      "page_context:#{page_name}:#{family.id}:#{cache_version}"
    end

    # Override in subclasses to invalidate cache on data changes
    def cache_version
      "v1"
    end

    def read_cache
      Rails.cache.read(cache_key)
    end

    def write_cache(prompts)
      Rails.cache.write(cache_key, prompts, expires_in: CACHE_TTL)
    end

    def clear_cache
      Rails.cache.delete(cache_key)
    end

    def t(key, **options)
      I18n.t("ai_prompts.#{page_name}.#{key}", **options)
    end

    def build_prompt(icon:, text:, category: :general)
      { icon: icon, text: text, category: category }
    end

    # Helper to get period for common queries
    def current_period
      @current_period ||= Period.last_30_days
    end
end
