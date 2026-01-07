# frozen_string_literal: true

# AskAI component - A reusable AI interaction trigger that can be placed throughout the app.
# Supports button mode (collapsed) and expanded input mode.
#
# Usage:
#   render DS::AskAi.new                           # Default button
#   render DS::AskAi.new(variant: :pill)           # Pill-shaped button
#   render DS::AskAi.new(placeholder: "Ask...")    # Custom placeholder
#   render DS::AskAi.new(context: :transactions)   # Page context for suggestions
class DS::AskAi < DesignSystemComponent
  VARIANTS = %w[button pill].freeze

  attr_reader :variant, :placeholder, :context, :metadata, :opts

  def initialize(variant: :button, placeholder: nil, context: nil, metadata: {}, **opts)
    @variant = variant.to_sym
    @placeholder = placeholder
    @context = context
    @metadata = metadata
    @opts = opts
  end

  def placeholder_text
    placeholder || I18n.t("components.ask_ai.placeholder")
  end

  def button_classes
    base_classes = "inline-flex items-center gap-2 font-medium transition-colors"

    variant_classes = case variant
    when :pill
      "px-3 py-1.5 rounded-full bg-container shadow-border-xs hover:bg-surface-hover text-sm"
    else
      "px-3 py-2 rounded-lg bg-container shadow-border-xs hover:bg-surface-hover text-sm"
    end

    class_names(base_classes, variant_classes, opts[:class])
  end

  def input_container_classes
    "flex items-center gap-2 bg-container px-3 py-2 rounded-lg shadow-border-xs w-full max-w-md"
  end

  def input_classes
    "flex-1 bg-transparent border-0 focus:ring-0 text-sm text-primary placeholder:text-subdued"
  end

  def form_url
    helpers.chats_path
  end

  def stimulus_controller
    "DS--ask-ai"
  end

  def stimulus_values
    values = { expanded: false }
    values[:context] = context.to_s if context.present?
    values[:metadata] = metadata.to_json if metadata.present?
    values
  end

  def merged_data
    data = opts[:data] || {}
    stimulus_key = stimulus_controller.tr("-", "_")

    stimulus_data = stimulus_values.transform_keys { |k| "#{stimulus_key}_#{k}_value" }

    data.merge(
      controller: [ stimulus_controller, data[:controller] ].compact.join(" "),
      **stimulus_data,
      action: data[:action]
    )
  end

  def default_ai_model
    helpers.default_ai_model
  end

  # Sanitize metadata to prevent XSS when rendering as JSON
  def sanitize_metadata_json
    return "{}" if metadata.blank?

    # Only allow string, number, boolean, and nil values
    safe_metadata = metadata.transform_values do |value|
      case value
      when String, Numeric, TrueClass, FalseClass, NilClass
        value
      else
        value.to_s
      end
    end

    safe_metadata.to_json
  end
end
