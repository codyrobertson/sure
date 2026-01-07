require "test_helper"

class DS::AskAiComponentTest < ViewComponent::TestCase
  setup do
    @family = families(:dylan_family)
    @user = users(:family_admin)
    Current.session = @user.sessions.create!
  end

  teardown do
    Current.reset
  end

  test "renders with default button variant" do
    render_inline DS::AskAi.new

    assert_selector "button[data-DS--ask-ai-target='button']"
    assert_text I18n.t("components.ask_ai.button_text")
  end

  test "renders with pill variant" do
    render_inline DS::AskAi.new(variant: :pill)

    assert_selector "button.rounded-full"
  end

  test "renders with custom placeholder" do
    custom_placeholder = "Ask me anything"
    render_inline DS::AskAi.new(placeholder: custom_placeholder)

    assert_selector "textarea[placeholder='#{custom_placeholder}']"
  end

  test "renders with context value" do
    render_inline DS::AskAi.new(context: :transactions)

    assert_selector "input[name='page_context'][value='transactions']", visible: :all
  end

  test "renders dialog with proper ARIA attributes" do
    render_inline DS::AskAi.new

    assert_selector "[role='dialog'][aria-modal='true']"
    assert_selector "[aria-labelledby]"
    assert_selector "h2.sr-only"
  end

  test "generates unique ID for each instance" do
    html1 = render_inline(DS::AskAi.new).to_html
    html2 = render_inline(DS::AskAi.new).to_html

    # Extract IDs from the rendered HTML
    id1 = html1.match(/id="(ask-ai-[a-f0-9]+)"/)[1]
    id2 = html2.match(/id="(ask-ai-[a-f0-9]+)"/)[1]

    assert_not_equal id1, id2, "Each component instance should have a unique ID"
  end

  test "button has correct aria-controls matching dialog ID" do
    component = DS::AskAi.new
    html = render_inline(component).to_html

    # Extract the dialog ID and the aria-controls value
    dialog_id = html.match(/id="(ask-ai-[a-f0-9]+)" role="dialog"/)[1]
    aria_controls = html.match(/aria-controls="(ask-ai-[a-f0-9]+)"/)[1]

    assert_equal dialog_id, aria_controls, "aria-controls should match the dialog ID"
  end

  test "sanitizes metadata to prevent XSS" do
    malicious_metadata = {
      script: "<script>alert('xss')</script>",
      normal: "safe_value",
      number: 42
    }

    component = DS::AskAi.new(metadata: malicious_metadata)
    json = component.sanitize_metadata_json

    parsed = JSON.parse(json)
    assert_equal "<script>alert('xss')</script>", parsed["script"]
    assert_equal "safe_value", parsed["normal"]
    assert_equal 42, parsed["number"]
  end

  test "sanitize_metadata_json returns empty object for blank metadata" do
    component = DS::AskAi.new(metadata: {})
    assert_equal "{}", component.sanitize_metadata_json

    component2 = DS::AskAi.new(metadata: nil)
    assert_equal "{}", component2.sanitize_metadata_json
  end

  test "placeholder_text falls back to i18n default" do
    component = DS::AskAi.new
    assert_equal I18n.t("components.ask_ai.placeholder"), component.placeholder_text
  end

  test "placeholder_text uses custom placeholder when provided" do
    custom = "Custom prompt"
    component = DS::AskAi.new(placeholder: custom)
    assert_equal custom, component.placeholder_text
  end

  test "stimulus values include context when provided" do
    component = DS::AskAi.new(context: :dashboard)
    values = component.stimulus_values

    assert_equal "dashboard", values[:context]
  end

  test "stimulus values exclude context when not provided" do
    component = DS::AskAi.new
    values = component.stimulus_values

    assert_not values.key?(:context)
  end

  test "merged_data includes stimulus controller" do
    component = DS::AskAi.new
    data = component.merged_data

    assert_includes data[:controller], "DS--ask-ai"
  end

  test "renders form targeting chats_path" do
    render_inline DS::AskAi.new

    assert_selector "form[action='#{chats_path}']", visible: :all
  end

  test "renders hidden ai_model field" do
    render_inline DS::AskAi.new

    assert_selector "input[name='chat[ai_model]']", visible: :all
  end

  test "renders metadata hidden field only when metadata present" do
    # Without metadata
    render_inline DS::AskAi.new
    assert_no_selector "input[name='metadata']", visible: :all

    # With metadata
    render_inline DS::AskAi.new(metadata: { key: "value" })
    assert_selector "input[name='metadata']", visible: :all
  end
end
