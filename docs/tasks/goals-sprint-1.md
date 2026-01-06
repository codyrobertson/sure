# Sprint 1: Goals & Savings Tracking MVP

## Sprint Overview

**Sprint Goal**: Deliver a functional MVP for goals and savings tracking where users can create, manage, and track progress toward financial goals.

**Duration**: 2 weeks (10 working days)

**Team Size**: 1-2 engineers

**Deliverables**:
1. Goal data model with progress calculation
2. Full CRUD interface for managing goals
3. Dashboard widget showing active goals
4. Comprehensive test coverage
5. Documentation

---

## Sprint Backlog

### Epic 1: Goal Data Model & Core Business Logic (Days 1-2)

#### T1: Create Goals Table Migration

**Priority**: Critical
**Estimated Complexity**: Small (S)
**Estimated Time**: 1-2 hours
**Dependencies**: None
**Assignee**: Backend Engineer

**Description**:
Create a database migration to add the `goals` table with all necessary columns, foreign keys, and indexes.

**Acceptance Criteria**:
- [ ] Migration creates `goals` table with correct column types
- [ ] Foreign keys to `families` and `accounts` tables are defined
- [ ] Indexes created for performance (family_id, account_id, status)
- [ ] Migration is reversible (can rollback cleanly)
- [ ] Schema.rb reflects correct structure after migration

**Files to Create**:
- `db/migrate/[timestamp]_create_goals.rb`

**Files to Modify**:
- `db/schema.rb` (auto-updated)

**Implementation Notes**:
```ruby
# Columns needed:
# - id: uuid (primary key)
# - family_id: uuid (not null, foreign key)
# - account_id: uuid (not null, foreign key)
# - name: string (not null)
# - description: text
# - target_amount: decimal(19,4) (not null)
# - starting_balance: decimal(19,4)
# - target_date: date (nullable)
# - currency: string (not null)
# - status: string (default: 'active')
# - created_at: timestamp
# - updated_at: timestamp

# Indexes needed:
# - index on family_id
# - index on account_id
# - index on status
# - composite index on (family_id, status) for dashboard queries
```

**Testing**:
- Run `bin/rails db:migrate` and verify success
- Run `bin/rails db:rollback` and verify rollback works
- Run `bin/rails db:migrate` again to confirm idempotence

---

#### T2: Create Goal Model with Validations

**Priority**: Critical
**Estimated Complexity**: Medium (M)
**Estimated Time**: 2-3 hours
**Dependencies**: T1
**Assignee**: Backend Engineer

**Description**:
Create the Goal model with associations, validations, monetization, and status enum.

**Acceptance Criteria**:
- [ ] Goal model exists with proper associations
- [ ] Validations enforce data integrity
- [ ] Monetizable concern configured for currency fields
- [ ] Status enum includes all states
- [ ] Scopes defined for common queries
- [ ] Inverse associations added to Account and Family models

**Files to Create**:
- `app/models/goal.rb`

**Files to Modify**:
- `app/models/account.rb` (add has_many :goals)
- `app/models/family.rb` (add has_many :goals)

**Implementation Notes**:
```ruby
class Goal < ApplicationRecord
  include Monetizable

  belongs_to :family
  belongs_to :account

  validates :name, :target_amount, :currency, :account_id, :family_id, presence: true
  validates :target_amount, numericality: { greater_than: 0 }
  validate :currency_matches_account

  monetize :target_amount, :starting_balance

  enum :status, { active: 'active', completed: 'completed', paused: 'paused', archived: 'archived' },
       validate: true

  scope :active, -> { where(status: 'active') }
  scope :completed, -> { where(status: 'completed') }
  scope :for_account, ->(account_id) { where(account_id: account_id) }
  scope :chronological, -> { order(created_at: :desc) }
  scope :by_target_date, -> { order(Arel.sql('target_date IS NULL, target_date ASC')) }

  private

  def currency_matches_account
    return if account.nil?
    errors.add(:currency, "must match account currency") if currency != account.currency
  end
end
```

**Testing**:
- Open Rails console: `bin/rails console`
- Create a goal: `Goal.create!(family: Family.first, account: Account.first, name: "Test", target_amount: 1000, currency: "USD")`
- Verify validations work by trying invalid data

---

#### T3: Implement Goal Progress Calculation Logic

**Priority**: Critical
**Estimated Complexity**: Medium (M)
**Estimated Time**: 2-3 hours
**Dependencies**: T2
**Assignee**: Backend Engineer

**Description**:
Add instance methods to Goal model for calculating progress, remaining amount, completion percentage, and tracking status.

**Acceptance Criteria**:
- [ ] `current_balance` method safely handles deleted accounts
- [ ] `progress_amount` calculates delta from starting_balance
- [ ] `completion_percentage` returns value between 0-100
- [ ] `remaining_amount` shows how much more is needed
- [ ] `on_track?` evaluates if goal is on pace to meet target date
- [ ] All methods handle edge cases (nil values, negative progress)

**Files to Modify**:
- `app/models/goal.rb`

**Implementation Notes**:
```ruby
# Add to Goal model:

def current_balance
  account&.balance || 0
end

def progress_amount
  current_balance - (starting_balance || 0)
end

def completion_percentage
  return 0 if target_amount <= 0
  (progress_amount / target_amount.to_f * 100).clamp(0, 100).round(1)
end

def remaining_amount
  [target_amount - progress_amount, 0].max
end

def on_track?
  return true if target_date.nil?
  return true if Date.current > target_date # Past due, don't show "behind"

  days_elapsed = (Date.current - created_at.to_date).to_i
  total_days = (target_date - created_at.to_date).to_i
  return true if total_days <= 0

  expected_progress = target_amount * (days_elapsed.to_f / total_days)
  progress_amount >= expected_progress
end

def behind_schedule?
  return false if target_date.nil?
  !on_track? && Date.current <= target_date
end
```

**Testing**:
- Test in Rails console with various scenarios:
  - Goal with no target date
  - Goal on track
  - Goal behind schedule
  - Goal with past target date
  - Goal with negative progress

---

#### T4: Create Goal Model Tests

**Priority**: Critical
**Estimated Complexity**: Medium (M)
**Estimated Time**: 3-4 hours
**Dependencies**: T2, T3
**Assignee**: Backend Engineer

**Description**:
Write comprehensive Minitest tests for Goal model covering validations, associations, and calculation methods.

**Acceptance Criteria**:
- [ ] Fixtures created with representative goal data
- [ ] Validation tests cover all required fields
- [ ] Association tests verify relationships
- [ ] Progress calculation tests cover edge cases
- [ ] All tests pass
- [ ] Test coverage > 90% for Goal model

**Files to Create**:
- `test/fixtures/goals.yml`
- `test/models/goal_test.rb`

**Implementation Notes**:

**Fixtures** (`test/fixtures/goals.yml`):
```yaml
emergency_fund:
  family: dylan_family
  account: chase_checking
  name: "Emergency Fund"
  description: "Save 6 months of expenses"
  target_amount: 15000.00
  starting_balance: 5000.00
  target_date: <%= 6.months.from_now.to_date %>
  currency: "USD"
  status: "active"

vacation:
  family: dylan_family
  account: wells_fargo_savings
  name: "Summer Vacation"
  target_amount: 5000.00
  starting_balance: 1000.00
  target_date: <%= 3.months.from_now.to_date %>
  currency: "USD"
  status: "active"

completed_goal:
  family: dylan_family
  account: chase_checking
  name: "New Laptop"
  target_amount: 2000.00
  starting_balance: 0.00
  target_date: <%= 1.month.ago.to_date %>
  currency: "USD"
  status: "completed"
```

**Tests** (`test/models/goal_test.rb`):
```ruby
require "test_helper"

class GoalTest < ActiveSupport::TestCase
  setup do
    @goal = goals(:emergency_fund)
  end

  # Validation Tests
  test "should validate presence of name" do
    @goal.name = nil
    assert_not @goal.valid?
    assert_includes @goal.errors[:name], "can't be blank"
  end

  test "should validate presence of target_amount" do
    @goal.target_amount = nil
    assert_not @goal.valid?
  end

  test "should validate target_amount is positive" do
    @goal.target_amount = -100
    assert_not @goal.valid?
  end

  test "should validate currency matches account" do
    @goal.currency = "EUR"
    assert_not @goal.valid?
    assert_includes @goal.errors[:currency], "must match account currency"
  end

  # Association Tests
  test "should belong to family" do
    assert_respond_to @goal, :family
    assert_instance_of Family, @goal.family
  end

  test "should belong to account" do
    assert_respond_to @goal, :account
    assert_instance_of Account, @goal.account
  end

  # Progress Calculation Tests
  test "current_balance returns account balance" do
    assert_equal @goal.account.balance, @goal.current_balance
  end

  test "current_balance returns 0 when account is deleted" do
    @goal.account.destroy
    @goal.reload
    assert_equal 0, @goal.current_balance
  end

  test "progress_amount calculates delta correctly" do
    # Assuming account balance increased by 500
    starting = @goal.starting_balance
    current = @goal.current_balance
    expected_progress = current - starting
    assert_equal expected_progress, @goal.progress_amount
  end

  test "completion_percentage returns value between 0 and 100" do
    percentage = @goal.completion_percentage
    assert percentage >= 0
    assert percentage <= 100
  end

  test "completion_percentage handles nil starting_balance" do
    @goal.starting_balance = nil
    assert_nothing_raised { @goal.completion_percentage }
  end

  test "remaining_amount shows how much more is needed" do
    remaining = @goal.remaining_amount
    assert remaining >= 0
  end

  test "on_track? returns true when no target date" do
    @goal.target_date = nil
    assert @goal.on_track?
  end

  test "on_track? evaluates progress correctly" do
    # Set up goal created 1 day ago with 10 days to target
    @goal.created_at = 1.day.ago
    @goal.target_date = 9.days.from_now
    @goal.starting_balance = 0
    @goal.target_amount = 100

    # Mock current balance to be on track (should have saved $10 in 1 day)
    @goal.account.update(balance: 15) # Ahead of schedule
    assert @goal.on_track?

    # Mock current balance to be behind (should have $10 but only have $5)
    @goal.account.update(balance: 5)
    assert_not @goal.on_track?
  end

  # Scope Tests
  test "active scope returns only active goals" do
    active_count = Goal.active.count
    assert_equal Goal.where(status: 'active').count, active_count
  end

  test "by_target_date scope orders correctly with nil dates last" do
    goals = Goal.by_target_date
    goals_with_dates = goals.reject { |g| g.target_date.nil? }
    assert_equal goals_with_dates.sort_by(&:target_date), goals_with_dates
  end
end
```

**Testing**:
- Run `bin/rails test test/models/goal_test.rb`
- Verify all tests pass
- Check coverage with SimpleCov if available

---

### Epic 2: Goal CRUD Interface (Days 3-6)

#### T5: Create Goals Controller with RESTful Actions

**Priority**: Critical
**Estimated Complexity**: Medium (M)
**Estimated Time**: 3-4 hours
**Dependencies**: T2, T3
**Assignee**: Backend Engineer

**Description**:
Build the goals controller with all standard RESTful actions (index, show, new, create, edit, update, destroy).

**Acceptance Criteria**:
- [ ] Controller has all RESTful actions
- [ ] Actions are scoped to Current.family
- [ ] Strong parameters configured correctly
- [ ] Redirects and flash messages work properly
- [ ] Starting balance auto-set from account on creation

**Files to Create**:
- `app/controllers/goals_controller.rb`

**Implementation Notes**:
```ruby
class GoalsController < ApplicationController
  before_action :set_goal, only: [:show, :edit, :update, :destroy]

  def index
    @goals = Current.family.goals.includes(:account).active.by_target_date
  end

  def show
    # Uses set_goal before_action
  end

  def new
    @goal = Current.family.goals.new
  end

  def create
    @goal = Current.family.goals.new(goal_params)

    # Auto-set starting_balance from account's current balance
    if @goal.account
      @goal.starting_balance = @goal.account.balance
    end

    if @goal.save
      redirect_to goals_path, notice: t("goals.create.success")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    # Uses set_goal before_action
  end

  def update
    if @goal.update(goal_params)
      redirect_to goal_path(@goal), notice: t("goals.update.success")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @goal.destroy
    redirect_to goals_path, notice: t("goals.destroy.success")
  end

  private

  def set_goal
    @goal = Current.family.goals.find(params[:id])
  end

  def goal_params
    params.require(:goal).permit(
      :name,
      :description,
      :target_amount,
      :target_date,
      :account_id,
      :currency,
      :status
    )
  end
end
```

**Testing**:
- Access routes in browser: `/goals`, `/goals/new`, etc.
- Verify redirects work
- Check flash messages display

---

#### T6: Create Goals Routes

**Priority**: Critical
**Estimated Complexity**: Small (S)
**Estimated Time**: 10 minutes
**Dependencies**: T5
**Assignee**: Backend Engineer

**Description**:
Add RESTful routes for goals resource.

**Acceptance Criteria**:
- [ ] Routes generate correct paths
- [ ] Routes require authentication
- [ ] All 7 RESTful routes present

**Files to Modify**:
- `config/routes.rb`

**Implementation Notes**:
```ruby
# Add inside authenticated scope:
resources :goals
```

**Testing**:
- Run `bin/rails routes | grep goals`
- Verify all routes present: index, show, new, create, edit, update, destroy

---

#### T7: Create Goal Form Partial

**Priority**: Critical
**Estimated Complexity**: Large (L)
**Estimated Time**: 4-5 hours
**Dependencies**: T5
**Assignee**: Frontend Engineer

**Description**:
Build a reusable form partial for creating and editing goals, with account selector and currency auto-population.

**Acceptance Criteria**:
- [ ] Form works for both new and edit actions
- [ ] Uses design system form components
- [ ] Account dropdown populated with user's accounts
- [ ] Currency auto-populated when account selected
- [ ] Validation errors display correctly
- [ ] All strings use i18n
- [ ] Form submits via Turbo

**Files to Create**:
- `app/views/goals/_form.html.erb`
- `app/javascript/controllers/goal_form_controller.js`

**Files to Modify**:
- `config/locales/en.yml` (add i18n keys)

**Implementation Notes**:

**Form View** (`app/views/goals/_form.html.erb`):
```erb
<%= form_with(model: goal, data: { controller: "goal-form" }) do |form| %>
  <% if goal.errors.any? %>
    <div class="bg-destructive/10 border border-destructive text-destructive px-4 py-3 rounded mb-4">
      <h3 class="font-medium mb-2"><%= t("goals.form.errors.title", count: goal.errors.count) %></h3>
      <ul class="list-disc list-inside">
        <% goal.errors.full_messages.each do |message| %>
          <li><%= message %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <div class="space-y-4">
    <div>
      <%= form.label :name, t("goals.form.name_label"), class: "block text-sm font-medium mb-1" %>
      <%= form.text_field :name,
          placeholder: t("goals.form.name_placeholder"),
          class: "w-full px-3 py-2 border border-primary rounded-lg focus:ring-2 focus:ring-gray-900" %>
    </div>

    <div>
      <%= form.label :description, t("goals.form.description_label"), class: "block text-sm font-medium mb-1" %>
      <%= form.text_area :description,
          placeholder: t("goals.form.description_placeholder"),
          rows: 3,
          class: "w-full px-3 py-2 border border-primary rounded-lg focus:ring-2 focus:ring-gray-900" %>
    </div>

    <div>
      <%= form.label :account_id, t("goals.form.account_label"), class: "block text-sm font-medium mb-1" %>
      <%= form.collection_select :account_id,
          Current.family.accounts.visible,
          :id,
          :name,
          { prompt: t("goals.form.account_prompt") },
          {
            class: "w-full px-3 py-2 border border-primary rounded-lg focus:ring-2 focus:ring-gray-900",
            data: {
              goal_form_target: "accountSelect",
              action: "change->goal-form#updateCurrency"
            }
          } %>
    </div>

    <div>
      <%= form.label :target_amount, t("goals.form.target_amount_label"), class: "block text-sm font-medium mb-1" %>
      <div class="flex items-center gap-2">
        <%= form.number_field :target_amount,
            step: "0.01",
            min: "0",
            placeholder: "10000.00",
            class: "flex-1 px-3 py-2 border border-primary rounded-lg focus:ring-2 focus:ring-gray-900" %>
        <span data-goal-form-target="currencyDisplay" class="text-sm text-secondary">
          <%= goal.currency || Current.family.currency %>
        </span>
      </div>
    </div>

    <%= form.hidden_field :currency, data: { goal_form_target: "currencyField" } %>

    <div>
      <%= form.label :target_date, t("goals.form.target_date_label"), class: "block text-sm font-medium mb-1" %>
      <%= form.date_field :target_date,
          class: "w-full px-3 py-2 border border-primary rounded-lg focus:ring-2 focus:ring-gray-900" %>
      <p class="text-xs text-secondary mt-1"><%= t("goals.form.target_date_help") %></p>
    </div>

    <div class="flex gap-3 pt-4">
      <%= form.submit t("goals.form.submit"),
          class: "btn btn-primary" %>
      <%= link_to t("goals.form.cancel"),
          goals_path,
          class: "btn btn-secondary" %>
    </div>
  </div>
<% end %>
```

**Stimulus Controller** (`app/javascript/controllers/goal_form_controller.js`):
```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["accountSelect", "currencyField", "currencyDisplay"]

  connect() {
    this.updateCurrency()
  }

  updateCurrency() {
    const selectedOption = this.accountSelectTarget.selectedOptions[0]
    if (selectedOption && selectedOption.dataset.currency) {
      const currency = selectedOption.dataset.currency
      this.currencyFieldTarget.value = currency
      this.currencyDisplayTarget.textContent = currency
    }
  }
}
```

**i18n Strings** (`config/locales/en.yml`):
```yaml
en:
  goals:
    form:
      name_label: "Goal Name"
      name_placeholder: "e.g., Emergency Fund, Summer Vacation"
      description_label: "Description (Optional)"
      description_placeholder: "What is this goal for?"
      account_label: "Linked Account"
      account_prompt: "Select an account..."
      target_amount_label: "Target Amount"
      target_date_label: "Target Date (Optional)"
      target_date_help: "Leave blank if there's no specific deadline"
      submit: "Save Goal"
      cancel: "Cancel"
      errors:
        title:
          one: "1 error prevented this goal from being saved"
          other: "%{count} errors prevented this goal from being saved"
    create:
      success: "Goal created successfully!"
    update:
      success: "Goal updated successfully!"
    destroy:
      success: "Goal deleted successfully!"
```

**Testing**:
- Visit `/goals/new`
- Fill out form and submit
- Verify account dropdown works
- Check currency updates automatically
- Test validation errors display

---

#### T8: Create Goals Index View

**Priority**: Critical
**Estimated Complexity**: Medium (M)
**Estimated Time**: 2-3 hours
**Dependencies**: T7
**Assignee**: Frontend Engineer

**Description**:
Build the goals listing page showing all user's active goals.

**Acceptance Criteria**:
- [ ] Page displays all active goals
- [ ] Shows goal name, progress, target, and linked account
- [ ] "New Goal" button navigates to form
- [ ] Empty state when no goals exist
- [ ] Responsive design
- [ ] All strings use i18n

**Files to Create**:
- `app/views/goals/index.html.erb`

**Files to Modify**:
- `config/locales/en.yml`

**Implementation Notes**:
```erb
<% content_for :page_header do %>
  <div class="flex justify-between items-center mb-6">
    <div>
      <h1 class="text-3xl font-medium text-primary">
        <%= t("goals.index.title") %>
      </h1>
      <p class="text-secondary mt-1">
        <%= t("goals.index.subtitle") %>
      </p>
    </div>
    <%= link_to new_goal_path, class: "btn btn-primary" do %>
      <%= icon("plus", size: "sm", class: "mr-2") %>
      <%= t("goals.index.new_goal") %>
    <% end %>
  </div>
<% end %>

<% if @goals.any? %>
  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
    <% @goals.each do |goal| %>
      <%= render GoalCardComponent.new(goal: goal, mode: "default") %>
    <% end %>
  </div>
<% else %>
  <div class="text-center py-12">
    <div class="inline-flex items-center justify-center w-16 h-16 bg-secondary/10 rounded-full mb-4">
      <%= icon("target", size: "lg", class: "text-secondary") %>
    </div>
    <h3 class="text-lg font-medium text-primary mb-2">
      <%= t("goals.index.empty_state.title") %>
    </h3>
    <p class="text-secondary mb-6">
      <%= t("goals.index.empty_state.description") %>
    </p>
    <%= link_to new_goal_path, class: "btn btn-primary" do %>
      <%= icon("plus", size: "sm", class: "mr-2") %>
      <%= t("goals.index.new_goal") %>
    <% end %>
  </div>
<% end %>
```

**i18n** (`config/locales/en.yml`):
```yaml
goals:
  index:
    title: "Goals"
    subtitle: "Track your savings goals and progress"
    new_goal: "New Goal"
    empty_state:
      title: "No goals yet"
      description: "Create your first savings goal to start tracking your progress"
```

**Testing**:
- Visit `/goals`
- Verify empty state shows when no goals
- Create a goal and verify it appears
- Check responsive layout

---

#### T9: Create Goals New and Edit Views

**Priority**: Critical
**Estimated Complexity**: Small (S)
**Estimated Time**: 1 hour
**Dependencies**: T7
**Assignee**: Frontend Engineer

**Description**:
Create simple views that render the form partial for creating and editing goals.

**Acceptance Criteria**:
- [ ] New view renders form
- [ ] Edit view renders form with existing data
- [ ] Breadcrumbs work correctly
- [ ] All strings use i18n

**Files to Create**:
- `app/views/goals/new.html.erb`
- `app/views/goals/edit.html.erb`

**Files to Modify**:
- `config/locales/en.yml`

**Implementation Notes**:

**New View** (`app/views/goals/new.html.erb`):
```erb
<% content_for :page_header do %>
  <nav class="mb-4" aria-label="Breadcrumb">
    <ol class="flex items-center space-x-2 text-sm">
      <li><%= link_to t("goals.index.title"), goals_path, class: "text-secondary hover:text-primary" %></li>
      <li class="text-secondary">/</li>
      <li class="text-primary"><%= t("goals.new.title") %></li>
    </ol>
  </nav>

  <h1 class="text-3xl font-medium text-primary">
    <%= t("goals.new.title") %>
  </h1>
<% end %>

<div class="max-w-2xl">
  <%= render "form", goal: @goal %>
</div>
```

**Edit View** (`app/views/goals/edit.html.erb`):
```erb
<% content_for :page_header do %>
  <nav class="mb-4" aria-label="Breadcrumb">
    <ol class="flex items-center space-x-2 text-sm">
      <li><%= link_to t("goals.index.title"), goals_path, class: "text-secondary hover:text-primary" %></li>
      <li class="text-secondary">/</li>
      <li><%= link_to @goal.name, goal_path(@goal), class: "text-secondary hover:text-primary" %></li>
      <li class="text-secondary">/</li>
      <li class="text-primary"><%= t("goals.edit.title") %></li>
    </ol>
  </nav>

  <h1 class="text-3xl font-medium text-primary">
    <%= t("goals.edit.title") %>
  </h1>
<% end %>

<div class="max-w-2xl">
  <%= render "form", goal: @goal %>
</div>
```

**i18n** (`config/locales/en.yml`):
```yaml
goals:
  new:
    title: "New Goal"
  edit:
    title: "Edit Goal"
```

**Testing**:
- Visit `/goals/new` and `/goals/:id/edit`
- Verify breadcrumbs work
- Verify form submits correctly

---

#### T10: Create Goals Show View

**Priority**: Medium (nice-to-have for Sprint 1)
**Estimated Complexity**: Medium (M)
**Estimated Time**: 2-3 hours
**Dependencies**: T9
**Assignee**: Frontend Engineer

**Description**:
Build the goal detail page showing comprehensive information about a single goal.

**Acceptance Criteria**:
- [ ] Page displays all goal information
- [ ] Progress displayed prominently with visual indicator
- [ ] Shows linked account with link
- [ ] Edit and delete buttons work
- [ ] Delete button shows confirmation
- [ ] All strings use i18n

**Files to Create**:
- `app/views/goals/show.html.erb`

**Files to Modify**:
- `config/locales/en.yml`

**Implementation Notes**:
```erb
<% content_for :page_header do %>
  <nav class="mb-4" aria-label="Breadcrumb">
    <ol class="flex items-center space-x-2 text-sm">
      <li><%= link_to t("goals.index.title"), goals_path, class: "text-secondary hover:text-primary" %></li>
      <li class="text-secondary">/</li>
      <li class="text-primary"><%= @goal.name %></li>
    </ol>
  </nav>

  <div class="flex justify-between items-start">
    <div>
      <h1 class="text-3xl font-medium text-primary">
        <%= @goal.name %>
      </h1>
      <% if @goal.description.present? %>
        <p class="text-secondary mt-2">
          <%= @goal.description %>
        </p>
      <% end %>
    </div>
    <div class="flex gap-2">
      <%= link_to edit_goal_path(@goal), class: "btn btn-secondary" do %>
        <%= icon("pencil", size: "sm", class: "mr-2") %>
        <%= t("goals.show.edit") %>
      <% end %>
      <%= button_to goal_path(@goal),
          method: :delete,
          data: { turbo_confirm: t("goals.show.delete_confirm") },
          class: "btn btn-destructive" do %>
        <%= icon("trash-2", size: "sm", class: "mr-2") %>
        <%= t("goals.show.delete") %>
      <% end %>
    </div>
  </div>
<% end %>

<div class="space-y-6">
  <!-- Progress Card -->
  <div class="bg-container rounded-xl shadow-border-xs p-6">
    <div class="flex justify-between items-baseline mb-4">
      <span class="text-sm font-medium text-secondary"><%= t("goals.show.progress") %></span>
      <span class="text-2xl font-bold text-primary">
        <%= @goal.completion_percentage.round(0) %>%
      </span>
    </div>

    <div class="relative h-4 bg-secondary/10 rounded-full overflow-hidden mb-4">
      <div class="absolute inset-y-0 left-0 bg-success transition-all duration-300"
           style="width: <%= @goal.completion_percentage %>%">
      </div>
    </div>

    <div class="grid grid-cols-2 gap-4 text-sm">
      <div>
        <p class="text-secondary mb-1"><%= t("goals.show.current_progress") %></p>
        <p class="text-xl font-semibold text-primary">
          <%= @goal.progress_amount_money.format %>
        </p>
      </div>
      <div>
        <p class="text-secondary mb-1"><%= t("goals.show.remaining") %></p>
        <p class="text-xl font-semibold text-primary">
          <%= @goal.remaining_amount_money.format %>
        </p>
      </div>
    </div>
  </div>

  <!-- Details Grid -->
  <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
    <div class="bg-container rounded-xl shadow-border-xs p-6">
      <h3 class="font-medium text-primary mb-4"><%= t("goals.show.details") %></h3>
      <dl class="space-y-3">
        <div>
          <dt class="text-sm text-secondary"><%= t("goals.show.target_amount") %></dt>
          <dd class="text-base font-medium text-primary"><%= @goal.target_amount_money.format %></dd>
        </div>
        <div>
          <dt class="text-sm text-secondary"><%= t("goals.show.target_date") %></dt>
          <dd class="text-base font-medium text-primary">
            <%= @goal.target_date ? l(@goal.target_date, format: :long) : t("goals.show.no_target_date") %>
          </dd>
        </div>
        <div>
          <dt class="text-sm text-secondary"><%= t("goals.show.status") %></dt>
          <dd class="text-base font-medium text-primary">
            <% if @goal.on_track? %>
              <span class="text-success"><%= t("goals.show.on_track") %></span>
            <% else %>
              <span class="text-warning"><%= t("goals.show.behind_schedule") %></span>
            <% end %>
          </dd>
        </div>
      </dl>
    </div>

    <div class="bg-container rounded-xl shadow-border-xs p-6">
      <h3 class="font-medium text-primary mb-4"><%= t("goals.show.linked_account") %></h3>
      <%= link_to account_path(@goal.account), class: "block hover:bg-secondary/5 rounded-lg p-4 -m-4 transition-colors" do %>
        <p class="font-medium text-primary mb-1"><%= @goal.account.name %></p>
        <p class="text-sm text-secondary mb-2"><%= @goal.account.long_subtype_label %></p>
        <p class="text-xl font-semibold text-primary">
          <%= @goal.account.balance_money.format %>
        </p>
      <% end %>
    </div>
  </div>

  <!-- Metadata -->
  <div class="bg-container rounded-xl shadow-border-xs p-6">
    <dl class="grid grid-cols-2 gap-4 text-sm">
      <div>
        <dt class="text-secondary"><%= t("goals.show.created_at") %></dt>
        <dd class="text-primary"><%= l(@goal.created_at, format: :long) %></dd>
      </div>
      <div>
        <dt class="text-secondary"><%= t("goals.show.updated_at") %></dt>
        <dd class="text-primary"><%= l(@goal.updated_at, format: :long) %></dd>
      </div>
    </dl>
  </div>
</div>
```

**i18n** (`config/locales/en.yml`):
```yaml
goals:
  show:
    edit: "Edit"
    delete: "Delete"
    delete_confirm: "Are you sure you want to delete this goal? This action cannot be undone."
    progress: "Progress"
    current_progress: "Current Progress"
    remaining: "Remaining"
    details: "Details"
    target_amount: "Target Amount"
    target_date: "Target Date"
    no_target_date: "No deadline set"
    status: "Status"
    on_track: "On Track"
    behind_schedule: "Behind Schedule"
    linked_account: "Linked Account"
    created_at: "Created"
    updated_at: "Last Updated"
```

**Testing**:
- Visit `/goals/:id`
- Verify all data displays correctly
- Test edit and delete buttons
- Check confirmation dialog

---

#### T11: Create Goal ViewComponent

**Priority**: Critical
**Estimated Complexity**: Medium (M)
**Estimated Time**: 2-3 hours
**Dependencies**: T2
**Assignee**: Frontend Engineer

**Description**:
Build a reusable ViewComponent for displaying goal cards across different views (index, dashboard).

**Acceptance Criteria**:
- [ ] Component renders goal summary with progress bar
- [ ] Supports different display modes (compact, default)
- [ ] Color-coded based on tracking status
- [ ] Reusable across multiple views
- [ ] Accessible (ARIA labels, keyboard navigation)

**Files to Create**:
- `app/components/goal_card_component.rb`
- `app/components/goal_card_component.html.erb`

**Implementation Notes**:

**Component Class** (`app/components/goal_card_component.rb`):
```ruby
class GoalCardComponent < ViewComponent::Base
  attr_reader :goal, :mode

  def initialize(goal:, mode: "default")
    @goal = goal
    @mode = mode
  end

  def progress_color_class
    return "bg-success" if goal.on_track?
    return "bg-warning" if goal.behind_schedule?
    "bg-secondary"
  end

  def card_class
    base = "bg-container rounded-xl shadow-border-xs hover:shadow-border-md transition-shadow"
    mode == "compact" ? "#{base} p-4" : "#{base} p-6"
  end

  def show_description?
    mode == "default" && goal.description.present?
  end
end
```

**Component Template** (`app/components/goal_card_component.html.erb`):
```erb
<%= link_to goal_path(goal), class: card_class do %>
  <div class="space-y-3">
    <!-- Header -->
    <div class="flex justify-between items-start gap-2">
      <div class="flex-1 min-w-0">
        <h3 class="font-medium text-primary truncate">
          <%= goal.name %>
        </h3>
        <% if show_description? %>
          <p class="text-sm text-secondary mt-1 line-clamp-2">
            <%= goal.description %>
          </p>
        <% end %>
      </div>
      <span class="text-sm font-medium text-primary shrink-0">
        <%= goal.completion_percentage.round(0) %>%
      </span>
    </div>

    <!-- Progress Bar -->
    <div class="relative h-2 bg-secondary/10 rounded-full overflow-hidden">
      <div class="absolute inset-y-0 left-0 <%= progress_color_class %> transition-all duration-300"
           style="width: <%= goal.completion_percentage %>%"
           role="progressbar"
           aria-valuenow="<%= goal.completion_percentage.round(0) %>"
           aria-valuemin="0"
           aria-valuemax="100"
           aria-label="<%= t('components.goal_card.progress_label', name: goal.name) %>">
      </div>
    </div>

    <!-- Amounts -->
    <div class="flex justify-between items-baseline text-sm">
      <div>
        <span class="text-secondary"><%= t('components.goal_card.current') %>:</span>
        <span class="font-medium text-primary ml-1">
          <%= goal.progress_amount_money.format %>
        </span>
      </div>
      <div>
        <span class="text-secondary"><%= t('components.goal_card.target') %>:</span>
        <span class="font-medium text-primary ml-1">
          <%= goal.target_amount_money.format %>
        </span>
      </div>
    </div>

    <!-- Footer -->
    <div class="flex justify-between items-center text-xs text-secondary pt-2 border-t border-primary">
      <span class="flex items-center gap-1">
        <%= icon("credit-card", size: "xs") %>
        <%= goal.account.name %>
      </span>
      <% if goal.target_date.present? %>
        <span class="flex items-center gap-1">
          <%= icon("calendar", size: "xs") %>
          <%= l(goal.target_date, format: :short) %>
        </span>
      <% end %>
    </div>
  </div>
<% end %>
```

**i18n** (`config/locales/en.yml`):
```yaml
components:
  goal_card:
    progress_label: "Progress for %{name}"
    current: "Current"
    target: "Target"
```

**Testing**:
- Render component in Rails console
- Check different modes
- Verify accessibility attributes
- Test with different goal states

---

#### T12: Write Goals Controller Tests

**Priority**: Critical
**Estimated Complexity**: Large (L)
**Estimated Time**: 4-5 hours
**Dependencies**: T5, T11
**Assignee**: Backend Engineer

**Description**:
Write comprehensive tests for all goals controller actions including authorization, redirects, and flash messages.

**Acceptance Criteria**:
- [ ] Tests cover all controller actions
- [ ] Tests verify family-scoped authorization
- [ ] Tests check successful and failure cases
- [ ] Tests verify redirects and flash messages
- [ ] All tests pass

**Files to Create**:
- `test/controllers/goals_controller_test.rb`

**Implementation Notes**:
```ruby
require "test_helper"

class GoalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:dylan) # Adjust to your test helper
    @goal = goals(:emergency_fund)
    @other_family_goal = goals(:other_family_goal) # Create this fixture
  end

  # Index Tests
  test "should get index" do
    get goals_url
    assert_response :success
    assert_select "h1", text: I18n.t("goals.index.title")
  end

  test "index only shows current family goals" do
    get goals_url
    assert_includes @response.body, @goal.name
    assert_not_includes @response.body, @other_family_goal.name
  end

  # Show Tests
  test "should show goal" do
    get goal_url(@goal)
    assert_response :success
    assert_select "h1", text: @goal.name
  end

  test "should not show other family's goal" do
    assert_raises(ActiveRecord::RecordNotFound) do
      get goal_url(@other_family_goal)
    end
  end

  # New Tests
  test "should get new" do
    get new_goal_url
    assert_response :success
    assert_select "form"
  end

  # Create Tests
  test "should create goal with valid params" do
    assert_difference("Goal.count", 1) do
      post goals_url, params: {
        goal: {
          name: "New Goal",
          target_amount: 5000,
          account_id: accounts(:chase_checking).id,
          currency: "USD"
        }
      }
    end

    assert_redirected_to goals_path
    follow_redirect!
    assert_select ".flash", text: /created successfully/i
  end

  test "should set starting_balance on create" do
    account = accounts(:chase_checking)
    post goals_url, params: {
      goal: {
        name: "Test Goal",
        target_amount: 1000,
        account_id: account.id,
        currency: "USD"
      }
    }

    goal = Goal.last
    assert_equal account.balance, goal.starting_balance
  end

  test "should not create goal with invalid params" do
    assert_no_difference("Goal.count") do
      post goals_url, params: {
        goal: {
          name: "",
          target_amount: nil,
          account_id: nil
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select ".error"
  end

  # Edit Tests
  test "should get edit" do
    get edit_goal_url(@goal)
    assert_response :success
    assert_select "form"
  end

  test "should not edit other family's goal" do
    assert_raises(ActiveRecord::RecordNotFound) do
      get edit_goal_url(@other_family_goal)
    end
  end

  # Update Tests
  test "should update goal with valid params" do
    patch goal_url(@goal), params: {
      goal: {
        name: "Updated Name",
        target_amount: 20000
      }
    }

    assert_redirected_to goal_path(@goal)
    follow_redirect!
    assert_select ".flash", text: /updated successfully/i

    @goal.reload
    assert_equal "Updated Name", @goal.name
    assert_equal 20000, @goal.target_amount
  end

  test "should not update goal with invalid params" do
    original_name = @goal.name
    patch goal_url(@goal), params: {
      goal: {
        name: "",
        target_amount: -100
      }
    }

    assert_response :unprocessable_entity
    @goal.reload
    assert_equal original_name, @goal.name
  end

  test "should not update other family's goal" do
    assert_raises(ActiveRecord::RecordNotFound) do
      patch goal_url(@other_family_goal), params: {
        goal: { name: "Hacked" }
      }
    end
  end

  # Destroy Tests
  test "should destroy goal" do
    assert_difference("Goal.count", -1) do
      delete goal_url(@goal)
    end

    assert_redirected_to goals_path
    follow_redirect!
    assert_select ".flash", text: /deleted successfully/i
  end

  test "should not destroy other family's goal" do
    assert_no_difference("Goal.count") do
      assert_raises(ActiveRecord::RecordNotFound) do
        delete goal_url(@other_family_goal)
      end
    end
  end
end
```

**Testing**:
- Run `bin/rails test test/controllers/goals_controller_test.rb`
- Verify all tests pass
- Check test coverage

---

### Epic 3: Dashboard Goals Widget (Days 7-8)

#### T13: Add Goals Section to Dashboard

**Priority**: High
**Estimated Complexity**: Medium (M)
**Estimated Time**: 2-3 hours
**Dependencies**: T11
**Assignee**: Full Stack Engineer

**Description**:
Integrate goals widget into the dashboard as a collapsible, sortable section.

**Acceptance Criteria**:
- [ ] Goals section appears on dashboard
- [ ] Shows up to 5 active goals
- [ ] Section is collapsible
- [ ] Section is sortable (drag and drop)
- [ ] Only visible when user has goals
- [ ] Uses GoalCardComponent in compact mode
- [ ] "View All Goals" link present

**Files to Modify**:
- `app/controllers/pages_controller.rb`
- `app/models/user.rb` (dashboard section order)
- `config/locales/en.yml`

**Files to Create**:
- `app/views/pages/dashboard/_goals.html.erb`

**Implementation Notes**:

**Controller** (`app/controllers/pages_controller.rb`):
```ruby
# In build_dashboard_sections method, add to all_sections array:
{
  key: "goals",
  title: "pages.dashboard.goals.title",
  partial: "pages/dashboard/goals",
  locals: { goals: Current.family.goals.active.by_target_date.limit(5) },
  visible: Current.family.goals.active.any?,
  collapsible: true
}
```

**Dashboard Partial** (`app/views/pages/dashboard/_goals.html.erb`):
```erb
<div class="px-4 space-y-3">
  <% if goals.any? %>
    <div class="space-y-3">
      <% goals.each do |goal| %>
        <%= render GoalCardComponent.new(goal: goal, mode: "compact") %>
      <% end %>
    </div>

    <div class="pt-3 text-center">
      <%= link_to goals_path, class: "text-sm text-secondary hover:text-primary transition-colors inline-flex items-center gap-1" do %>
        <%= t("pages.dashboard.goals.view_all") %>
        <%= icon("arrow-right", size: "xs") %>
      <% end %>
    </div>
  <% else %>
    <div class="text-center py-8">
      <p class="text-secondary mb-4">
        <%= t("pages.dashboard.goals.empty_state") %>
      </p>
      <%= link_to new_goal_path, class: "btn btn-sm btn-primary" do %>
        <%= icon("plus", size: "xs", class: "mr-1") %>
        <%= t("pages.dashboard.goals.create_first") %>
      <% end %>
    </div>
  <% end %>
</div>
```

**User Model** (`app/models/user.rb`):
```ruby
# Update dashboard_section_order method to include 'goals'
def dashboard_section_order
  preferences["section_order"] || [
    "cashflow_sankey",
    "outflows_donut",
    "inflows_donut",
    "net_worth_chart",
    "goals",  # Add this line
    "balance_sheet"
  ]
end
```

**i18n** (`config/locales/en.yml`):
```yaml
pages:
  dashboard:
    goals:
      title: "Goals"
      view_all: "View all goals"
      empty_state: "No active goals. Create your first goal to start tracking progress."
      create_first: "Create Goal"
```

**Testing**:
- Visit dashboard
- Verify goals section appears
- Test collapsing/expanding
- Test drag and drop reordering
- Verify "View All" link works

---

#### T14: Add Goals Navigation Link

**Priority**: Medium
**Estimated Complexity**: Small (S)
**Estimated Time**: 30 minutes
**Dependencies**: T6
**Assignee**: Frontend Engineer

**Description**:
Add goals link to main navigation menu.

**Acceptance Criteria**:
- [ ] Link appears in navigation
- [ ] Link is highlighted when on goals pages
- [ ] Follows design system patterns
- [ ] Uses i18n

**Files to Modify**:
- `app/views/layouts/_navigation.html.erb` (or similar nav partial)
- `config/locales/en.yml`

**Implementation Notes**:

Find the navigation partial (likely in `app/views/layouts/` or `app/views/shared/`) and add:

```erb
<%= link_to goals_path,
    class: "nav-link #{'active' if current_page?(goals_path) || controller_name == 'goals'}" do %>
  <%= icon("target", size: "sm", class: "mr-2") %>
  <%= t("navigation.goals") %>
<% end %>
```

**i18n** (`config/locales/en.yml`):
```yaml
navigation:
  goals: "Goals"
```

**Testing**:
- Check navigation menu
- Click link and verify it goes to goals index
- Verify active state works

---

## Sprint Schedule (10 Days)

### Day 1: Foundation Setup
- **Morning**: T1 (Migration) + T2 (Model)
- **Afternoon**: T3 (Progress Calculations)
- **Evening**: Begin T4 (Model Tests)

### Day 2: Complete Model Layer
- **Morning**: Complete T4 (Model Tests)
- **Afternoon**: Review and refine model logic
- **Evening**: Start T5 (Controller)

### Day 3: Controller and Routes
- **Morning**: Complete T5 (Controller)
- **Afternoon**: T6 (Routes) + Start T7 (Form)
- **Evening**: Continue T7 (Form)

### Day 4: Forms and Views
- **Morning**: Complete T7 (Form)
- **Afternoon**: T8 (Index View)
- **Evening**: T9 (New/Edit Views)

### Day 5: Components
- **Morning**: T11 (GoalCardComponent)
- **Afternoon**: Integrate component into views
- **Evening**: Start T12 (Controller Tests)

### Day 6: Testing
- **Morning**: Complete T12 (Controller Tests)
- **Afternoon**: Fix any failing tests
- **Evening**: Start T10 (Show View - optional)

### Day 7: Dashboard Integration
- **Morning**: Complete T10 (Show View)
- **Afternoon**: T13 (Dashboard Widget)
- **Evening**: T14 (Navigation Link)

### Day 8: Polish and Bug Fixes
- **Morning**: Manual testing and bug fixes
- **Afternoon**: UI polish, responsive design
- **Evening**: Accessibility improvements

### Day 9: QA and Documentation
- **Morning**: Comprehensive QA testing
- **Afternoon**: Write documentation
- **Evening**: Performance testing

### Day 10: Final Review and Deploy Prep
- **Morning**: Code review
- **Afternoon**: Final bug fixes
- **Evening**: Prepare demo, update changelog

---

## Risk Mitigation Checklist

Before marking Sprint 1 complete, verify these high-risk items are handled:

- [ ] **Account Deletion**: Add callback to handle goals when account deleted
- [ ] **Currency Mismatch**: Validation ensures goal.currency == account.currency
- [ ] **Starting Balance**: Auto-set from account.balance at creation time
- [ ] **Negative Progress**: UI handles and displays appropriately
- [ ] **Performance**: Dashboard loads goals with eager loading (no N+1)
- [ ] **Authorization**: All actions scoped to Current.family
- [ ] **Error Handling**: All edge cases handled gracefully
- [ ] **i18n**: All strings localized
- [ ] **Tests**: > 90% coverage on Goal model and controller

---

## Definition of Done

Sprint 1 is complete when:

### Code Quality
- [ ] All tests passing (`bin/rails test`)
- [ ] No RuboCop violations (`bin/rubocop -f github -a`)
- [ ] No ERB lint violations (`bundle exec erb_lint ./app/**/*.erb -a`)
- [ ] No Brakeman security issues (`bin/brakeman --no-pager`)

### Functionality
- [ ] User can create a goal via form
- [ ] User can view all goals on index page
- [ ] User can edit existing goals
- [ ] User can delete goals with confirmation
- [ ] Goals display on dashboard (when present)
- [ ] Progress calculation is accurate
- [ ] All views are responsive (mobile + desktop)

### Testing
- [ ] Manual test: Create goal → verify on index → edit → delete
- [ ] Manual test: View goals on dashboard
- [ ] Manual test: Test with no goals (empty states)
- [ ] Manual test: Test with deleted account
- [ ] Manual test: Currency auto-population works
- [ ] All automated tests pass

### Documentation
- [ ] Epic document complete and reviewed
- [ ] Sprint 1 tasks document complete
- [ ] Code comments for complex logic
- [ ] README updated if needed

### Demo Ready
- [ ] Demo script prepared
- [ ] Sample data seeded for demo
- [ ] Screenshots captured for changelog/release notes

---

## Success Metrics

After Sprint 1 ships, track:

1. **Adoption**: % of active users who create at least one goal in first week
2. **Engagement**: Average goals per user
3. **Quality**: Zero critical bugs reported in first 48 hours
4. **Performance**: Dashboard load time < 500ms with goals widget
5. **Test Coverage**: > 90% for Goal model and GoalsController

---

## Next Steps (Post-Sprint 1)

Prepare for Sprint 2:
- [ ] Gather user feedback on MVP
- [ ] Prioritize Phase 2 features (categories, forecasting, multi-account)
- [ ] Design goal detail page with progress chart
- [ ] Plan AI assistant integration
- [ ] Consider budget integration architecture

---

## Questions to Resolve During Sprint

1. Should completed goals be archived automatically or require manual action?
2. What happens when a goal's target date passes but it's not complete?
3. Should there be a notification system for goal milestones?
4. Do we need goal priority/ranking in v1?
5. Should goals show on account detail pages?

---

## Team Roles

**Backend Engineer**:
- T1, T2, T3, T4 (Model layer)
- T5, T6 (Controller and routes)
- T12 (Controller tests)
- Half of T13 (Dashboard backend)

**Frontend Engineer**:
- T7 (Form)
- T8, T9, T10 (Views)
- T11 (ViewComponent)
- T14 (Navigation)
- Half of T13 (Dashboard UI)

**Full Stack (if 1 person)**:
- All tasks sequentially following day-by-day schedule

---

## Daily Standup Template

**Yesterday**: [What was completed]
**Today**: [What will be worked on]
**Blockers**: [Any impediments]
**Progress**: [X/14 tasks complete, Y% done]

---

## Sprint Retrospective Questions

After Sprint 1:
1. What went well?
2. What could be improved?
3. Were estimates accurate?
4. Were there any surprises or hidden work?
5. What should we do differently in Sprint 2?

---

**End of Sprint 1 Task Document**
