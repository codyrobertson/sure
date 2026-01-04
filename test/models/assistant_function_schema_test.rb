require "test_helper"

class AssistantFunctionSchemaTest < ActiveSupport::TestCase
  FUNCTION_CLASSES = [
    Assistant::Function::GetCashFlow,
    Assistant::Function::GetTransactions,
    Assistant::Function::GetRecurringTransactions,
    Assistant::Function::GetIncomeStatement,
    Assistant::Function::CategorizeTransactions,
    Assistant::Function::TagTransactions,
    Assistant::Function::UpdateTransactions,
    Assistant::Function::CreateCategory,
    Assistant::Function::UpdateCategory,
    Assistant::Function::DeleteCategory,
    Assistant::Function::CreateTag,
    Assistant::Function::CreateRule,
    Assistant::Function::GenerateTimeSeriesChart,
    Assistant::Function::GenerateDonutChart,
    Assistant::Function::GenerateSankeyChart,
    Assistant::Function::GenerateAccountBalanceChart,
    Assistant::Function::WebSearch,
    Assistant::Function::FindRelatedTransactions,
    Assistant::Function::SuggestOptions
  ].freeze

  setup do
    @user = users(:family_admin)
  end

  test "all function schemas include additionalProperties: false at root level" do
    errors = []

    FUNCTION_CLASSES.each do |function_class|
      function = function_class.new(@user)
      schema = function.params_schema

      unless schema[:additionalProperties] == false
        errors << "#{function_class.name} is missing 'additionalProperties: false' in params_schema"
      end
    end

    assert errors.empty?, "Schema validation failed:\n#{errors.join("\n")}"
  end

  test "all function schemas have required type: object" do
    errors = []

    FUNCTION_CLASSES.each do |function_class|
      function = function_class.new(@user)
      schema = function.params_schema

      unless schema[:type] == "object"
        errors << "#{function_class.name} params_schema must have type: 'object'"
      end
    end

    assert errors.empty?, "Schema validation failed:\n#{errors.join("\n")}"
  end

  test "all function schemas have properties and required keys" do
    errors = []

    FUNCTION_CLASSES.each do |function_class|
      function = function_class.new(@user)
      schema = function.params_schema

      unless schema.key?(:properties)
        errors << "#{function_class.name} params_schema missing 'properties' key"
      end

      unless schema.key?(:required)
        errors << "#{function_class.name} params_schema missing 'required' key"
      end
    end

    assert errors.empty?, "Schema validation failed:\n#{errors.join("\n")}"
  end

  test "nested object schemas include additionalProperties: false" do
    errors = []

    FUNCTION_CLASSES.each do |function_class|
      function = function_class.new(@user)
      schema = function.params_schema

      check_nested_objects(schema[:properties], function_class.name, errors)
    end

    assert errors.empty?, "Nested schema validation failed:\n#{errors.join("\n")}"
  end

  test "all functions can be instantiated and return valid definitions" do
    FUNCTION_CLASSES.each do |function_class|
      function = function_class.new(@user)

      assert_nothing_raised("#{function_class.name} failed to generate definition") do
        definition = function.to_definition

        assert definition[:name].present?, "#{function_class.name} missing name"
        assert definition[:description].present?, "#{function_class.name} missing description"
        assert definition[:params_schema].is_a?(Hash), "#{function_class.name} params_schema must be a Hash"
      end
    end
  end

  # Tests for infer_strict_mode - OpenAI strict mode requires ALL properties in required array
  test "all function definitions include strict key as boolean" do
    FUNCTION_CLASSES.each do |function_class|
      function = function_class.new(@user)
      definition = function.to_definition

      assert definition.key?(:strict), "#{function_class.name} definition missing :strict key"
      assert [true, false].include?(definition[:strict]),
        "#{function_class.name} :strict must be boolean, got #{definition[:strict].class}"
    end
  end

  test "strict mode correctly inferred from schema structure for all functions" do
    FUNCTION_CLASSES.each do |function_class|
      function = function_class.new(@user)
      schema = function.params_schema
      definition = function.to_definition

      properties = schema[:properties]&.keys&.map(&:to_s)&.sort || []
      required = schema[:required]&.map(&:to_s)&.sort || []
      expected_strict = properties == required

      assert_equal expected_strict, definition[:strict],
        "#{function_class.name} strict mode mismatch: " \
        "properties=#{properties}, required=#{required}, expected strict=#{expected_strict}"
    end
  end

  test "infer_strict_mode returns true when all properties are required" do
    function = Assistant::Function::CreateTag.new(@user)
    schema = function.params_schema

    # CreateTag has only 'name' property and it's required
    assert_equal ["name"], schema[:properties].keys.map(&:to_s)
    assert_equal ["name"], schema[:required].map(&:to_s)
    assert function.to_definition[:strict], "CreateTag should be strict (all properties required)"
  end

  test "infer_strict_mode returns false when some properties are optional" do
    function = Assistant::Function::GetTransactions.new(@user)
    schema = function.params_schema

    # GetTransactions has many properties but only 'order' and 'page' are required
    assert schema[:properties].keys.size > 2, "GetTransactions should have more than 2 properties"
    assert_equal 2, schema[:required].size
    refute function.to_definition[:strict], "GetTransactions should not be strict (has optional params)"
  end

  test "infer_strict_mode returns false when no properties are required" do
    function = Assistant::Function::GetCashFlow.new(@user)
    schema = function.params_schema

    # GetCashFlow has 'period' property but it's optional
    assert schema[:properties].keys.any?, "GetCashFlow should have properties"
    assert_equal [], schema[:required]
    refute function.to_definition[:strict], "GetCashFlow should not be strict (all params optional)"
  end

  private

  def check_nested_objects(properties, context, errors)
    return unless properties.is_a?(Hash)

    properties.each do |key, prop|
      next unless prop.is_a?(Hash)

      if prop[:type] == "object" && prop[:properties].present?
        unless prop[:additionalProperties] == false
          errors << "#{context}.#{key} nested object missing 'additionalProperties: false'"
        end

        # Recursively check nested objects
        check_nested_objects(prop[:properties], "#{context}.#{key}", errors)
      end

      # Check array items that are objects
      if prop[:type] == "array" && prop[:items].is_a?(Hash) && prop[:items][:type] == "object"
        unless prop[:items][:additionalProperties] == false
          errors << "#{context}.#{key}[] items missing 'additionalProperties: false'"
        end

        check_nested_objects(prop[:items][:properties], "#{context}.#{key}[]", errors)
      end
    end
  end
end
