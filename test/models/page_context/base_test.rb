require "test_helper"

class PageContext::BaseTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @user = users(:family_admin)
  end

  test "raises NotImplementedError for abstract methods" do
    context = PageContext::Base.new(family: @family, user: @user)

    assert_raises(NotImplementedError) { context.page_name }
    assert_raises(NotImplementedError) { context.page_icon }
    assert_raises(NotImplementedError) { context.send(:generate_prompts) }
  end

  test "initializes with family, user, and metadata" do
    metadata = { key: "value" }
    context = PageContext::Base.new(family: @family, user: @user, metadata: metadata)

    assert_equal @family, context.family
    assert_equal @user, context.user
    assert_equal "value", context.metadata[:key]
  end

  test "metadata is empty hash by default" do
    context = PageContext::Base.new(family: @family, user: @user)

    assert_equal({}, context.metadata)
  end

  test "available? returns true by default" do
    context = PageContext::Base.new(family: @family, user: @user)

    assert context.available?
  end
end
