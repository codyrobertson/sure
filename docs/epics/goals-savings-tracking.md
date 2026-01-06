# EPIC: Goals & Savings Tracking

## A. Goals & Context

### Product Goals
- Enable users to set financial goals with target amounts and deadlines
- Track progress toward goals in real-time based on actual account balances
- Provide visual feedback and forecasting to motivate goal completion
- Integrate goals into the AI assistant for intelligent recommendations
- Surface goals prominently on dashboard to maintain user focus

### Technical Goals
- Build a flexible goal system that can link to one or more accounts
- Leverage existing account and balance infrastructure for progress tracking
- Create reusable UI components following the app's design system
- Integrate with the AI assistant function architecture
- Ensure proper test coverage for critical business logic

### Business Value
- **User Retention**: Goals create recurring engagement touchpoints
- **Data Insights**: Goal patterns reveal user financial priorities
- **Differentiation**: Advanced goal forecasting sets app apart from competitors
- **Upsell Opportunity**: Premium features (e.g., multiple goals, advanced forecasting)

### Constraints
- Must follow Rails conventions (skinny controllers, fat models)
- Must use Hotwire (Turbo + Stimulus) for interactivity, not heavy JS
- Must integrate with existing dashboard section architecture
- Must support i18n for all user-facing strings
- Must work with existing Minitest + fixtures testing approach
- Database changes require migrations

### Assumptions
- Users primarily want savings goals (not debt payoff goals in v1)
- Goals should track balance increases, not transaction patterns
- Target date is optional (some goals are open-ended)
- Users may want to allocate funds from one account to multiple goals
- AI assistant should be able to query and suggest actions on goals

### Missing Info / Questions

**Critical Questions:**
1. Should a goal track a single account, or aggregate across multiple accounts?
   - **Decision**: Start with single account per goal (simpler MVP), add multi-account in v2

2. Should goals have categories (emergency fund, vacation, house down payment)?
   - **Decision**: Yes, use predefined categories with icon + color

3. How should "automatic" contributions work? Track actual balance changes or expected recurring amounts?
   - **Decision**: Track actual balance changes (no manual contribution logging in v1)

4. Should goals be linked to budgets (e.g., "save $500/month from surplus")?
   - **Decision**: No budget integration in v1, but design schema to allow it later

5. What happens when an account balance decreases? Show negative progress?
   - **Decision**: Yes, show actual progress including decreases (with visual indicator)

6. Should there be goal templates (e.g., "3-6 months emergency fund")?
   - **Decision**: Yes, but as a v2 feature (Sprint 2+)

## B. Phase Plan

### Phase 1: Foundation & Core CRUD (Sprint 1)
**Goal**: Users can create, view, edit, and delete savings goals with basic progress tracking

**In-Scope**:
- Goal model with validations
- CRUD operations (create, read, update, delete)
- Single account association per goal
- Basic progress calculation based on account balance deltas
- Dashboard widget showing active goals
- Simple list view of all goals

**Out-of-Scope**:
- Multi-account goals
- Goal categories/templates
- Forecasting/predictions
- AI assistant integration
- Advanced visualizations

**Exit Criteria**:
- All tests passing for Goal model and controller
- User can create a goal with name, target amount, target date, and linked account
- Dashboard shows goals widget with progress bars
- User can edit and delete goals
- Progress accurately reflects account balance changes since goal creation

**Timeline**: 1 sprint (2 weeks)

---

### Phase 2: Enhanced UX & Forecasting (Sprint 2)
**Goal**: Rich user experience with goal forecasting and smart insights

**In-Scope**:
- Goal categories with icons and colors
- Completion forecasting based on historical savings rate
- Detailed goal page with progress chart over time
- Goal milestones (25%, 50%, 75%, 100%)
- Notifications for milestone achievements
- Goal templates (emergency fund, house, vacation, etc.)
- Multi-account goal support

**Out-of-Scope**:
- AI assistant integration
- Goal sharing between family members
- Recurring contribution tracking
- Budget integration

**Exit Criteria**:
- Goal categories implemented with visual distinction
- Forecasting algorithm calculates expected completion date
- Goal detail page renders with historical progress chart
- Templates allow quick goal creation
- Tests cover forecasting logic edge cases

**Timeline**: 1 sprint (2 weeks)

---

### Phase 3: AI Integration & Intelligence (Sprint 3)
**Goal**: AI assistant can query, suggest, and help manage goals

**In-Scope**:
- Assistant function: `get_goals` - retrieve user's goals
- Assistant function: `create_goal` - create a goal from chat
- Assistant function: `update_goal` - modify goal parameters
- AI-powered goal suggestions based on spending patterns
- Natural language goal queries ("How close am I to my vacation goal?")
- Smart recommendations ("You're spending too much to hit your goal on time")

**Out-of-Scope**:
- Voice-based goal management
- Goal sharing with other users
- Integration with external goal-tracking apps

**Exit Criteria**:
- All three assistant functions working and tested
- AI can accurately answer goal-related questions
- AI provides actionable recommendations
- Function calls broadcast data changes to update UI

**Timeline**: 1 sprint (2 weeks)

---

### Phase 4: Polish & Advanced Features (Sprint 4)
**Goal**: Production-ready feature with edge case handling and advanced capabilities

**In-Scope**:
- Goal prioritization (rank goals by importance)
- Budget integration (allocate surplus to goals)
- "What-if" scenarios (forecast with different contribution amounts)
- Goal activity feed (history of changes)
- Improved mobile UX
- Performance optimizations (caching, eager loading)
- Comprehensive error handling
- Edge case handling (negative balances, deleted accounts, etc.)

**Out-of-Scope**:
- Social features (sharing goals with friends)
- Gamification (badges, streaks)
- Investment goal tracking (separate feature)

**Exit Criteria**:
- All edge cases covered with tests
- Performance benchmarks met (< 200ms for goal list, < 500ms for dashboard)
- Error messages provide clear user guidance
- Mobile UX matches desktop experience
- Documentation complete

**Timeline**: 1 sprint (2 weeks)

## C. Epics & Tasks

### EPIC-1: Goal Data Model & Core Business Logic
**Objective**: Build the foundational goal model with validations, associations, and progress calculation logic

**User Impact**: Users can store goal data and see accurate progress based on account balance changes

**Tech Scope**:
- Database migration for `goals` table
- `Goal` model with validations
- Association: `Goal` belongs_to `Account`
- Association: `Account` has_many `Goals`
- Progress calculation logic in model
- Model tests with fixtures

**Dependencies**:
- None (foundational work)

**Done-When**:
- Migration creates `goals` table with all required columns
- Goal model validates presence of name, target_amount, and account_id
- Goal model calculates progress_percentage based on starting_balance and current account balance
- Goal model has methods: `progress_amount`, `remaining_amount`, `completion_percentage`, `on_track?`
- Tests cover happy path and edge cases (deleted account, negative balance, etc.)
- All tests pass

**Docs Required**:
- **/docs/models/goal.md** - Document goal attributes, validations, and business logic

---

### EPIC-2: Goal CRUD Interface
**Objective**: Build controllers and views for creating, reading, updating, and deleting goals

**User Impact**: Users can manage their goals through a web interface

**Tech Scope**:
- `GoalsController` with RESTful actions (index, show, new, create, edit, update, destroy)
- Views: `goals/index.html.erb`, `goals/new.html.erb`, `goals/edit.html.erb`, `goals/show.html.erb`
- Forms with account selector dropdown
- ViewComponent for goal card (reusable across views)
- Stimulus controller for form interactions
- Routes configuration
- Controller tests

**Dependencies**:
- EPIC-1 (Goal model must exist)

**Done-When**:
- User can navigate to `/goals` and see list of their goals
- User can click "New Goal" and create a goal via form
- Form validates required fields and shows errors
- User can edit existing goals
- User can delete goals with confirmation
- All views use i18n for strings
- Controller tests cover all actions
- ViewComponent renders correctly with different goal states

**Docs Required**:
- **/docs/ui/goal-components.md** - Document ViewComponent API and usage

---

### EPIC-3: Dashboard Goals Widget
**Objective**: Add a collapsible goals section to the dashboard showing active goals with progress bars

**User Impact**: Users see their goals every time they open the app, maintaining focus and motivation

**Tech Scope**:
- Dashboard section configuration in `PagesController#build_dashboard_sections`
- Partial: `pages/dashboard/_goals.html.erb`
- ViewComponent: `GoalProgressCardComponent`
- Stimulus controller: `goal_progress_controller.js` (optional, for interactions)
- CSS for progress bars using Tailwind functional tokens
- i18n strings for dashboard section

**Dependencies**:
- EPIC-1 (Goal model)
- EPIC-2 (Goal views and components)

**Done-When**:
- Dashboard shows "Goals" section after net worth chart
- Section displays up to 5 active goals with progress bars
- Progress bar uses color coding (green = on track, yellow = at risk, red = behind)
- Each goal card links to detail view
- Section is collapsible like other dashboard sections
- Section respects user's dashboard preferences (collapsed state, sort order)
- Section only appears if user has at least one goal
- All strings localized

**Docs Required**:
- **/docs/dashboard/goals-widget.md** - Document widget behavior and customization

---

### EPIC-4: Goal Progress Calculation Engine
**Objective**: Build robust logic to calculate goal progress, savings rate, and forecasting

**User Impact**: Users get accurate progress updates and realistic completion forecasts

**Tech Scope**:
- `Goal#calculate_progress` - determine current progress vs target
- `Goal#savings_rate` - calculate average savings per month/week
- `Goal#forecast_completion_date` - predict when goal will be reached
- `Goal#on_track?` - boolean check if pacing to meet target date
- `Goal::ProgressCalculator` service object for complex calculations
- Handle edge cases: deleted accounts, negative balance changes, paused goals
- Unit tests for all calculation methods

**Dependencies**:
- EPIC-1 (Goal model)

**Done-When**:
- Progress calculation handles all edge cases without errors
- Savings rate calculation uses historical balance data (from `balances` table)
- Forecast is reasonably accurate (within 10% for linear savings patterns)
- `on_track?` method correctly identifies goals at risk
- All calculation methods have comprehensive test coverage
- Performance is acceptable (< 50ms per goal)

**Docs Required**:
- **/docs/models/goal-calculations.md** - Document calculation algorithms and formulas

## D. Units of Work (UOW) - Sprint 1

### Epic 1: Goal Data Model & Core Business Logic

#### Task T1 - Create Goals Table Migration
**Belongs to**: EPIC-1
**Description**: Create a database migration to add the `goals` table with all necessary columns
**Acceptance Criteria**:
- Migration creates `goals` table with proper column types and constraints
- Includes foreign key to `accounts` table
- Includes indexes for performance
- Migration is reversible

**UOW Breakdown**:

- **UOW-1.1 - Write Goals Table Migration**
  - Type: data
  - Exact Action: Generate migration file `db/migrate/XXXXXX_create_goals.rb` with columns: id (uuid), family_id (uuid, not null), account_id (uuid, not null), name (string, not null), description (text), target_amount (decimal, precision 19 scale 4, not null), starting_balance (decimal, precision 19 scale 4), target_date (date), currency (string, not null), status (string, default: 'active'), created_at, updated_at. Add foreign keys and indexes.
  - Estimate: 1 hour
  - Dependencies: None
  - Acceptance Checks:
    - Migration file exists and follows naming convention
    - All columns have correct types and constraints
    - Foreign keys reference correct tables
    - Includes indexes on family_id, account_id, and status

- **UOW-1.2 - Run Migration and Verify Schema**
  - Type: data
  - Exact Action: Run `bin/rails db:migrate` and verify schema.rb includes goals table with correct structure
  - Estimate: 15 minutes
  - Dependencies: UOW-1.1
  - Acceptance Checks:
    - Migration runs without errors
    - `db/schema.rb` includes goals table definition
    - Can rollback and re-run migration successfully

---

#### Task T2 - Create Goal Model with Validations
**Belongs to**: EPIC-1
**Description**: Create the Goal model with associations, validations, and monetization
**Acceptance Criteria**:
- Model includes proper associations to Family and Account
- Validates required fields
- Uses Monetizable concern for currency fields
- Includes status enum

**UOW Breakdown**:

- **UOW-2.1 - Create Goal Model File**
  - Type: backend
  - Exact Action: Create `/Users/Cody/code_projects/sure/app/models/goal.rb` with class definition including: belongs_to :family, belongs_to :account, validates :name, :target_amount, :currency, :account_id, :family_id presence: true, monetize :target_amount, :starting_balance, enum :status active: 'active', completed: 'completed', paused: 'paused', archived: 'archived'
  - Estimate: 1 hour
  - Dependencies: UOW-1.2
  - Acceptance Checks:
    - Model file exists at correct path
    - Associations defined correctly
    - Validations enforce required fields
    - Monetization configured for currency fields
    - Status enum includes all states

- **UOW-2.2 - Add Inverse Associations to Account and Family**
  - Type: backend
  - Exact Action: Edit `/Users/Cody/code_projects/sure/app/models/account.rb` to add `has_many :goals, dependent: :destroy` and edit `/Users/Cody/code_projects/sure/app/models/family.rb` to add `has_many :goals, dependent: :destroy`
  - Estimate: 15 minutes
  - Dependencies: UOW-2.1
  - Acceptance Checks:
    - Account model includes goals association
    - Family model includes goals association
    - Dependent destroy is configured to prevent orphaned records

- **UOW-2.3 - Add Goal Scopes**
  - Type: backend
  - Exact Action: Add scopes to Goal model: `scope :active, -> { where(status: 'active') }`, `scope :completed, -> { where(status: 'completed') }`, `scope :for_account, ->(account_id) { where(account_id: account_id) }`, `scope :chronological, -> { order(created_at: :desc) }`, `scope :by_target_date, -> { order(Arel.sql('target_date IS NULL, target_date ASC')) }`
  - Estimate: 30 minutes
  - Dependencies: UOW-2.1
  - Acceptance Checks:
    - All scopes return correct records
    - Scopes can be chained
    - Null target dates handled correctly in ordering

---

#### Task T3 - Implement Goal Progress Calculation Logic
**Belongs to**: EPIC-1
**Description**: Add methods to Goal model to calculate progress, remaining amount, and completion percentage
**Acceptance Criteria**:
- Methods correctly calculate progress based on account balance changes
- Handles edge cases (negative progress, account deleted, nil starting_balance)
- Performance is acceptable

**UOW Breakdown**:

- **UOW-3.1 - Add current_balance Method**
  - Type: backend
  - Exact Action: Add method to Goal model: `def current_balance` that returns `account&.balance || 0`, safely handling deleted accounts
  - Estimate: 15 minutes
  - Dependencies: UOW-2.1
  - Acceptance Checks:
    - Returns account balance when account exists
    - Returns 0 when account is deleted
    - Does not raise errors

- **UOW-3.2 - Add progress_amount Method**
  - Type: backend
  - Exact Action: Add method `def progress_amount` that calculates `current_balance - (starting_balance || 0)`, returning the delta in account balance since goal creation
  - Estimate: 20 minutes
  - Dependencies: UOW-3.1
  - Acceptance Checks:
    - Calculates correct delta
    - Handles nil starting_balance
    - Can return negative values (balance decreased)

- **UOW-3.3 - Add completion_percentage Method**
  - Type: backend
  - Exact Action: Add method `def completion_percentage` that returns `(progress_amount / target_amount.to_f * 100).clamp(0, 100).round(1)` to show progress as percentage
  - Estimate: 20 minutes
  - Dependencies: UOW-3.2
  - Acceptance Checks:
    - Returns value between 0 and 100
    - Handles division by zero
    - Rounds to 1 decimal place

- **UOW-3.4 - Add remaining_amount Method**
  - Type: backend
  - Exact Action: Add method `def remaining_amount` that returns `[target_amount - progress_amount, 0].max` to show how much more is needed
  - Estimate: 15 minutes
  - Dependencies: UOW-3.2
  - Acceptance Checks:
    - Returns positive value or zero
    - Never returns negative
    - Uses Money objects for proper formatting

- **UOW-3.5 - Add on_track? Method**
  - Type: backend
  - Exact Action: Add method `def on_track?` that returns true if no target_date or if progress_amount is >= expected_progress_by_now, where expected_progress_by_now = target_amount * (days_elapsed / total_days)
  - Estimate: 1 hour
  - Dependencies: UOW-3.2
  - Acceptance Checks:
    - Returns true when ahead of schedule
    - Returns false when behind schedule
    - Returns true when no target date set
    - Handles dates in the past

---

#### Task T4 - Create Goal Model Tests
**Belongs to**: EPIC-1
**Description**: Write comprehensive tests for Goal model validations and methods
**Acceptance Criteria**:
- Tests cover happy path and edge cases
- Uses fixtures, not factories
- All tests pass

**UOW Breakdown**:

- **UOW-4.1 - Create Goal Fixtures**
  - Type: tests
  - Exact Action: Create `/Users/Cody/code_projects/sure/test/fixtures/goals.yml` with 3 fixtures: `emergency_fund` (active, with target date), `vacation` (active, no target date), `completed_goal` (completed status)
  - Estimate: 30 minutes
  - Dependencies: UOW-2.1
  - Acceptance Checks:
    - Fixtures are valid and load without errors
    - Cover different goal states
    - Use existing account and family fixtures

- **UOW-4.2 - Write Goal Validation Tests**
  - Type: tests
  - Exact Action: Create `/Users/Cody/code_projects/sure/test/models/goal_test.rb` with tests for: validates presence of name, target_amount, currency, account_id, family_id; validates numericality of target_amount (must be positive); validates monetization of target_amount and starting_balance
  - Estimate: 1 hour
  - Dependencies: UOW-4.1
  - Acceptance Checks:
    - All validation tests pass
    - Tests enforce required fields
    - Tests catch invalid data

- **UOW-4.3 - Write Goal Progress Calculation Tests**
  - Type: tests
  - Exact Action: Add tests to goal_test.rb for: current_balance method, progress_amount method (positive and negative), completion_percentage method (0%, 50%, 100%, over 100%), remaining_amount method, on_track? method (on track, behind, no target date)
  - Estimate: 1.5 hours
  - Dependencies: UOW-4.2, UOW-3.1, UOW-3.2, UOW-3.3, UOW-3.4, UOW-3.5
  - Acceptance Checks:
    - All calculation tests pass
    - Edge cases covered (nil values, deleted accounts)
    - Tests use fixtures for data

- **UOW-4.4 - Write Goal Association Tests**
  - Type: tests
  - Exact Action: Add tests for belongs_to :account, belongs_to :family, dependent destroy behavior (deleting account archives goals or handles gracefully)
  - Estimate: 45 minutes
  - Dependencies: UOW-4.1
  - Acceptance Checks:
    - Association tests pass
    - Cascade delete behavior works correctly
    - Orphaned records prevented

---

### Epic 2: Goal CRUD Interface

#### Task T5 - Create Goals Controller with RESTful Actions
**Belongs to**: EPIC-2
**Description**: Build the goals controller with all CRUD actions
**Acceptance Criteria**:
- Controller has index, show, new, create, edit, update, destroy actions
- Uses strong parameters
- Scopes goals to Current.family
- Redirects and flash messages work correctly

**UOW Breakdown**:

- **UOW-5.1 - Generate Goals Controller**
  - Type: backend
  - Exact Action: Create `/Users/Cody/code_projects/sure/app/controllers/goals_controller.rb` with class definition including `before_action :set_goal, only: [:show, :edit, :update, :destroy]` and empty action methods: index, show, new, create, edit, update, destroy
  - Estimate: 30 minutes
  - Dependencies: UOW-2.1
  - Acceptance Checks:
    - Controller file exists
    - Inherits from ApplicationController
    - before_action configured correctly

- **UOW-5.2 - Implement Goals#index Action**
  - Type: backend
  - Exact Action: Implement index action to load `@goals = Current.family.goals.includes(:account).active.by_target_date` for listing all active goals
  - Estimate: 20 minutes
  - Dependencies: UOW-5.1
  - Acceptance Checks:
    - Loads goals scoped to current family
    - Eager loads account association
    - Orders by target date

- **UOW-5.3 - Implement Goals#show Action**
  - Type: backend
  - Exact Action: Implement show action (uses set_goal before_action, no additional code needed in action body)
  - Estimate: 10 minutes
  - Dependencies: UOW-5.1
  - Acceptance Checks:
    - set_goal loads correct goal
    - Raises 404 if goal not found

- **UOW-5.4 - Implement Goals#new and #create Actions**
  - Type: backend
  - Exact Action: Implement new action with `@goal = Current.family.goals.new` and create action with `@goal = Current.family.goals.new(goal_params)` that sets starting_balance from linked account, saves, and redirects to goals_path with success flash or re-renders new with errors
  - Estimate: 1 hour
  - Dependencies: UOW-5.1
  - Acceptance Checks:
    - New action initializes empty goal
    - Create action saves valid goals
    - Create action shows errors for invalid data
    - starting_balance auto-populated from account.balance
    - Flash messages displayed correctly

- **UOW-5.5 - Implement Goals#edit and #update Actions**
  - Type: backend
  - Exact Action: Implement edit action (uses set_goal) and update action with `@goal.update(goal_params)` that redirects to goal_path with success flash or re-renders edit with errors
  - Estimate: 45 minutes
  - Dependencies: UOW-5.1
  - Acceptance Checks:
    - Edit action loads existing goal
    - Update action saves changes
    - Update action shows errors for invalid data
    - Flash messages displayed correctly

- **UOW-5.6 - Implement Goals#destroy Action**
  - Type: backend
  - Exact Action: Implement destroy action that calls `@goal.destroy` and redirects to goals_path with success flash
  - Estimate: 20 minutes
  - Dependencies: UOW-5.1
  - Acceptance Checks:
    - Destroy action deletes goal
    - Redirects to index
    - Flash message confirms deletion

- **UOW-5.7 - Add Strong Parameters Method**
  - Type: backend
  - Exact Action: Add private method `def goal_params` that permits: :name, :description, :target_amount, :target_date, :account_id, :currency, :status
  - Estimate: 15 minutes
  - Dependencies: UOW-5.1
  - Acceptance Checks:
    - Only permitted params are allowed
    - Mass assignment protection works

- **UOW-5.8 - Add set_goal Private Method**
  - Type: backend
  - Exact Action: Add private method `def set_goal` that loads `@goal = Current.family.goals.find(params[:id])`
  - Estimate: 15 minutes
  - Dependencies: UOW-5.1
  - Acceptance Checks:
    - Loads goal by id
    - Scoped to current family
    - Raises ActiveRecord::RecordNotFound if not found

---

#### Task T6 - Create Goals Routes
**Belongs to**: EPIC-2
**Description**: Add routes for goals resource
**Acceptance Criteria**:
- Routes follow RESTful conventions
- Routes are scoped properly

**UOW Breakdown**:

- **UOW-6.1 - Add Goals Resource Routes**
  - Type: backend
  - Exact Action: Edit `/Users/Cody/code_projects/sure/config/routes.rb` to add `resources :goals` within the authenticated scope
  - Estimate: 10 minutes
  - Dependencies: UOW-5.1
  - Acceptance Checks:
    - Routes generate correct paths (goals_path, goal_path, etc.)
    - Routes require authentication
    - `bin/rails routes | grep goals` shows all 7 RESTful routes

---

#### Task T7 - Create Goal Form Partial
**Belongs to**: EPIC-2
**Description**: Build a reusable form partial for creating and editing goals
**Acceptance Criteria**:
- Form works for both new and edit actions
- Uses design system components
- Validates on client and server side
- All strings use i18n

**UOW Breakdown**:

- **UOW-7.1 - Create Goal Form Partial File**
  - Type: frontend
  - Exact Action: Create `/Users/Cody/code_projects/sure/app/views/goals/_form.html.erb` with form_with for goal model, using design system form components
  - Estimate: 1 hour
  - Dependencies: UOW-5.1
  - Acceptance Checks:
    - Form renders without errors
    - Form uses design system components
    - Form includes all goal fields

- **UOW-7.2 - Add Form Fields for Goal Attributes**
  - Type: frontend
  - Exact Action: Add form fields: text_field for :name, text_area for :description, number_field for :target_amount, date_field for :target_date (optional), select for :account_id (dropdown of user's accounts), hidden_field for :currency (auto-set from selected account)
  - Estimate: 1.5 hours
  - Dependencies: UOW-7.1
  - Acceptance Checks:
    - All fields render correctly
    - Account dropdown shows user's accounts
    - Currency auto-populated via Stimulus
    - Date field allows optional input

- **UOW-7.3 - Add Form Validation Errors Display**
  - Type: frontend
  - Exact Action: Add error message display using design system error component to show validation errors above form
  - Estimate: 30 minutes
  - Dependencies: UOW-7.1
  - Acceptance Checks:
    - Errors display when form submitted with invalid data
    - Uses design system error styling
    - Errors are user-friendly

- **UOW-7.4 - Add i18n Strings for Form**
  - Type: frontend
  - Exact Action: Update `/Users/Cody/code_projects/sure/config/locales/en.yml` to add keys under `goals.form.*` for all labels, placeholders, and buttons
  - Estimate: 30 minutes
  - Dependencies: UOW-7.1
  - Acceptance Checks:
    - All form strings use i18n
    - Keys follow naming convention
    - No hardcoded English strings in form

- **UOW-7.5 - Add Stimulus Controller for Account-to-Currency Sync**
  - Type: frontend
  - Exact Action: Create `/Users/Cody/code_projects/sure/app/javascript/controllers/goal_form_controller.js` with Stimulus controller that listens to account select change event and auto-populates currency field based on selected account's currency (stored in data attribute)
  - Estimate: 1 hour
  - Dependencies: UOW-7.2
  - Acceptance Checks:
    - Currency updates when account selected
    - Works without page reload
    - Handles edge cases (no account selected)

---

#### Task T8 - Create Goals Index View
**Belongs to**: EPIC-2
**Description**: Build the goals listing page
**Acceptance Criteria**:
- Shows all user's goals
- Links to create new goal
- Links to edit/delete each goal
- Responsive design

**UOW Breakdown**:

- **UOW-8.1 - Create Goals Index View File**
  - Type: frontend
  - Exact Action: Create `/Users/Cody/code_projects/sure/app/views/goals/index.html.erb` with page header, "New Goal" button, and empty state message if no goals exist
  - Estimate: 45 minutes
  - Dependencies: UOW-5.2
  - Acceptance Checks:
    - Page renders without errors
    - Header and button use design system
    - Empty state shows when no goals

- **UOW-8.2 - Add Goals List to Index View**
  - Type: frontend
  - Exact Action: Add iteration over @goals collection, rendering a goal card for each with: goal name, target amount, progress bar, linked account name, target date (if set), edit/delete action links
  - Estimate: 1.5 hours
  - Dependencies: UOW-8.1
  - Acceptance Checks:
    - All goals display
    - Progress bars show correct percentage
    - Links work correctly

- **UOW-8.3 - Add i18n Strings for Index View**
  - Type: frontend
  - Exact Action: Update `/Users/Cody/code_projects/sure/config/locales/en.yml` to add keys under `goals.index.*` for page title, empty state, button labels
  - Estimate: 20 minutes
  - Dependencies: UOW-8.1
  - Acceptance Checks:
    - All strings use i18n
    - Keys follow convention

---

#### Task T9 - Create Goals New and Edit Views
**Belongs to**: EPIC-2
**Description**: Build the goal creation and editing pages
**Acceptance Criteria**:
- New and edit views render form partial
- Views distinguish between create and update mode
- Breadcrumbs work correctly

**UOW Breakdown**:

- **UOW-9.1 - Create Goals New View**
  - Type: frontend
  - Exact Action: Create `/Users/Cody/code_projects/sure/app/views/goals/new.html.erb` with page header "New Goal", breadcrumbs, and render of form partial
  - Estimate: 30 minutes
  - Dependencies: UOW-7.1
  - Acceptance Checks:
    - Page renders form
    - Breadcrumbs show correct path
    - Form submits to create action

- **UOW-9.2 - Create Goals Edit View**
  - Type: frontend
  - Exact Action: Create `/Users/Cody/code_projects/sure/app/views/goals/edit.html.erb` with page header "Edit Goal", breadcrumbs, and render of form partial
  - Estimate: 30 minutes
  - Dependencies: UOW-7.1
  - Acceptance Checks:
    - Page renders form with existing data
    - Breadcrumbs show correct path
    - Form submits to update action

- **UOW-9.3 - Add i18n Strings for New/Edit Views**
  - Type: frontend
  - Exact Action: Update `/Users/Cody/code_projects/sure/config/locales/en.yml` to add keys under `goals.new.*` and `goals.edit.*` for page titles and breadcrumbs
  - Estimate: 15 minutes
  - Dependencies: UOW-9.1, UOW-9.2
  - Acceptance Checks:
    - All strings use i18n
    - Keys follow convention

---

#### Task T10 - Create Goals Show View
**Belongs to**: EPIC-2
**Description**: Build the goal detail page
**Acceptance Criteria**:
- Shows all goal information
- Displays progress prominently
- Links to edit and delete
- Shows linked account details

**UOW Breakdown**:

- **UOW-10.1 - Create Goals Show View File**
  - Type: frontend
  - Exact Action: Create `/Users/Cody/code_projects/sure/app/views/goals/show.html.erb` with page header showing goal name, breadcrumbs, and main content area
  - Estimate: 45 minutes
  - Dependencies: UOW-5.3
  - Acceptance Checks:
    - Page renders without errors
    - Header shows goal name
    - Breadcrumbs work correctly

- **UOW-10.2 - Add Goal Details to Show View**
  - Type: frontend
  - Exact Action: Add sections displaying: goal description, target amount (formatted), current progress amount (formatted), progress bar (large), completion percentage, remaining amount, target date (if set), linked account (with link), created date, last updated date
  - Estimate: 2 hours
  - Dependencies: UOW-10.1
  - Acceptance Checks:
    - All goal data displays
    - Money values formatted correctly
    - Progress bar visually prominent
    - Account link works

- **UOW-10.3 - Add Action Buttons to Show View**
  - Type: frontend
  - Exact Action: Add Edit and Delete buttons using design system components, Delete button includes confirmation dialog
  - Estimate: 30 minutes
  - Dependencies: UOW-10.1
  - Acceptance Checks:
    - Edit button links to edit view
    - Delete button shows confirmation
    - Delete button works correctly

- **UOW-10.4 - Add i18n Strings for Show View**
  - Type: frontend
  - Exact Action: Update `/Users/Cody/code_projects/sure/config/locales/en.yml` to add keys under `goals.show.*` for all labels and sections
  - Estimate: 30 minutes
  - Dependencies: UOW-10.1
  - Acceptance Checks:
    - All strings use i18n
    - Keys follow convention

---

#### Task T11 - Create Goal ViewComponent
**Belongs to**: EPIC-2
**Description**: Build a reusable ViewComponent for displaying goal cards
**Acceptance Criteria**:
- Component renders goal summary
- Reusable across index, show, and dashboard
- Supports different display modes (compact, detailed)

**UOW Breakdown**:

- **UOW-11.1 - Generate GoalCardComponent**
  - Type: frontend
  - Exact Action: Create `/Users/Cody/code_projects/sure/app/components/goal_card_component.rb` with component class accepting goal parameter and optional mode parameter (default: 'compact')
  - Estimate: 30 minutes
  - Dependencies: UOW-2.1
  - Acceptance Checks:
    - Component class exists
    - Accepts goal parameter
    - Mode parameter works

- **UOW-11.2 - Create GoalCardComponent Template**
  - Type: frontend
  - Exact Action: Create `/Users/Cody/code_projects/sure/app/components/goal_card_component.html.erb` with card layout showing: goal name, progress bar, current/target amounts, target date (if set), linked account name
  - Estimate: 1.5 hours
  - Dependencies: UOW-11.1
  - Acceptance Checks:
    - Template renders correctly
    - Uses design system components
    - Adapts to mode parameter

- **UOW-11.3 - Add Color Logic for Progress Bar**
  - Type: frontend
  - Exact Action: Add method to GoalCardComponent that returns color class based on goal status: green if on_track?, yellow if 50-90% to target date, red if < 50% to target date and behind schedule
  - Estimate: 45 minutes
  - Dependencies: UOW-11.1
  - Acceptance Checks:
    - Color logic works correctly
    - Uses design system color tokens
    - Handles edge cases (no target date)

- **UOW-11.4 - Add GoalCardComponent to Index View**
  - Type: frontend
  - Exact Action: Replace goal card HTML in index view with `<%= render GoalCardComponent.new(goal: goal) %>`
  - Estimate: 15 minutes
  - Dependencies: UOW-11.2, UOW-8.2
  - Acceptance Checks:
    - Component renders in index
    - Displays correctly
    - No regressions

---

#### Task T12 - Write Goals Controller Tests
**Belongs to**: EPIC-2
**Description**: Add comprehensive tests for goals controller actions
**Acceptance Criteria**:
- Tests cover all controller actions
- Tests verify authorization (goals scoped to family)
- Tests check redirects and flash messages

**UOW Breakdown**:

- **UOW-12.1 - Create Goals Controller Test File**
  - Type: tests
  - Exact Action: Create `/Users/Cody/code_projects/sure/test/controllers/goals_controller_test.rb` with test class and setup method that signs in a user
  - Estimate: 20 minutes
  - Dependencies: UOW-5.1
  - Acceptance Checks:
    - Test file exists
    - Setup method works
    - Can run tests

- **UOW-12.2 - Write Index Action Tests**
  - Type: tests
  - Exact Action: Add tests for: GET index returns success, assigns @goals variable, only shows current family's goals, renders correct template
  - Estimate: 45 minutes
  - Dependencies: UOW-12.1
  - Acceptance Checks:
    - All index tests pass
    - Tests use fixtures
    - Tests verify scoping

- **UOW-12.3 - Write Show Action Tests**
  - Type: tests
  - Exact Action: Add tests for: GET show returns success, assigns @goal variable, raises 404 for other family's goal
  - Estimate: 30 minutes
  - Dependencies: UOW-12.1
  - Acceptance Checks:
    - All show tests pass
    - Authorization enforced

- **UOW-12.4 - Write Create Action Tests**
  - Type: tests
  - Exact Action: Add tests for: POST create with valid params creates goal and redirects, POST create with invalid params re-renders form with errors, POST create sets starting_balance from account
  - Estimate: 1 hour
  - Dependencies: UOW-12.1
  - Acceptance Checks:
    - All create tests pass
    - Tests verify database changes
    - Tests check flash messages

- **UOW-12.5 - Write Update Action Tests**
  - Type: tests
  - Exact Action: Add tests for: PATCH update with valid params updates goal and redirects, PATCH update with invalid params re-renders form with errors, PATCH update only updates current family's goals
  - Estimate: 1 hour
  - Dependencies: UOW-12.1
  - Acceptance Checks:
    - All update tests pass
    - Tests verify database changes
    - Authorization enforced

- **UOW-12.6 - Write Destroy Action Tests**
  - Type: tests
  - Exact Action: Add tests for: DELETE destroy removes goal and redirects, DELETE destroy only deletes current family's goals, DELETE destroy shows flash message
  - Estimate: 45 minutes
  - Dependencies: UOW-12.1
  - Acceptance Checks:
    - All destroy tests pass
    - Tests verify database changes
    - Authorization enforced

---

### Epic 3: Dashboard Goals Widget

#### Task T13 - Add Goals Section to Dashboard
**Belongs to**: EPIC-3
**Description**: Integrate goals widget into dashboard layout
**Acceptance Criteria**:
- Goals section appears on dashboard
- Section follows existing dashboard pattern
- Section is collapsible and sortable
- Only shows when user has goals

**UOW Breakdown**:

- **UOW-13.1 - Add Goals Section to build_dashboard_sections**
  - Type: backend
  - Exact Action: Edit `/Users/Cody/code_projects/sure/app/controllers/pages_controller.rb` to add goals section to all_sections array in build_dashboard_sections method: `{ key: "goals", title: "pages.dashboard.goals.title", partial: "pages/dashboard/goals", locals: { goals: Current.family.goals.active.by_target_date.limit(5) }, visible: Current.family.goals.active.any?, collapsible: true }`
  - Estimate: 30 minutes
  - Dependencies: UOW-2.1
  - Acceptance Checks:
    - Section added to array
    - Section only visible when goals exist
    - Section follows same pattern as others

- **UOW-13.2 - Create Dashboard Goals Partial**
  - Type: frontend
  - Exact Action: Create `/Users/Cody/code_projects/sure/app/views/pages/dashboard/_goals.html.erb` with goals widget layout showing up to 5 active goals using GoalCardComponent in compact mode
  - Estimate: 1 hour
  - Dependencies: UOW-13.1, UOW-11.2
  - Acceptance Checks:
    - Partial renders without errors
    - Shows up to 5 goals
    - Uses GoalCardComponent

- **UOW-13.3 - Add "View All Goals" Link to Widget**
  - Type: frontend
  - Exact Action: Add link at bottom of goals widget using design system Link component that navigates to goals_path
  - Estimate: 15 minutes
  - Dependencies: UOW-13.2
  - Acceptance Checks:
    - Link renders correctly
    - Link navigates to goals index
    - Link uses design system component

- **UOW-13.4 - Add i18n Strings for Dashboard Goals Section**
  - Type: frontend
  - Exact Action: Update `/Users/Cody/code_projects/sure/config/locales/en.yml` to add keys under `pages.dashboard.goals.*` for section title, empty state, "View All" link text
  - Estimate: 15 minutes
  - Dependencies: UOW-13.2
  - Acceptance Checks:
    - All strings use i18n
    - Keys follow convention

- **UOW-13.5 - Update Default Dashboard Section Order**
  - Type: backend
  - Exact Action: Edit User model's dashboard_section_order method to include 'goals' in default section order array (insert after 'net_worth_chart')
  - Estimate: 15 minutes
  - Dependencies: UOW-13.1
  - Acceptance Checks:
    - Goals section appears in correct position
    - Existing users see section in default position
    - Section respects user's custom ordering

---

#### Task T14 - Add Goals Navigation Link
**Belongs to**: EPIC-2
**Description**: Add link to goals in main navigation
**Acceptance Criteria**:
- Goals link appears in navigation menu
- Link is highlighted when on goals pages
- Follows design system patterns

**UOW Breakdown**:

- **UOW-14.1 - Add Goals Link to Navigation**
  - Type: frontend
  - Exact Action: Edit navigation partial (likely `/Users/Cody/code_projects/sure/app/views/layouts/_navigation.html.erb` or similar) to add goals link after accounts link using same pattern as other nav items
  - Estimate: 30 minutes
  - Dependencies: UOW-6.1
  - Acceptance Checks:
    - Link appears in navigation
    - Link navigates to goals index
    - Link is highlighted when active
    - Link follows design system

- **UOW-14.2 - Add Navigation i18n String**
  - Type: frontend
  - Exact Action: Update `/Users/Cody/code_projects/sure/config/locales/en.yml` to add navigation label under appropriate nav keys
  - Estimate: 10 minutes
  - Dependencies: UOW-14.1
  - Acceptance Checks:
    - Nav label uses i18n
    - Key follows convention

---

## E. Delivery & Risk Plan

### Sprint 1 Mapping

**Sprint Theme**: Goals MVP - Foundation & CRUD

**Phase/Epic Priorities**:
1. EPIC-1: Goal Data Model (highest priority - blocking all other work)
2. EPIC-2: Goal CRUD Interface (delivers user value)
3. EPIC-3: Dashboard Goals Widget (polish and visibility)

**Must-Have UOWs** (Critical Path):
- Sprint 1 Week 1:
  - UOW-1.1, UOW-1.2 (migration)
  - UOW-2.1, UOW-2.2, UOW-2.3 (model)
  - UOW-3.1, UOW-3.2, UOW-3.3, UOW-3.4, UOW-3.5 (progress calculations)
  - UOW-4.1, UOW-4.2, UOW-4.3, UOW-4.4 (model tests)

- Sprint 1 Week 2:
  - UOW-5.1 through UOW-5.8 (controller)
  - UOW-6.1 (routes)
  - UOW-7.1 through UOW-7.5 (form)
  - UOW-8.1, UOW-8.2, UOW-8.3 (index view)
  - UOW-9.1, UOW-9.2, UOW-9.3 (new/edit views)
  - UOW-11.1, UOW-11.2, UOW-11.3, UOW-11.4 (ViewComponent)
  - UOW-12.1 through UOW-12.6 (controller tests)

**Nice-to-Have UOWs** (If time permits):
- UOW-10.1 through UOW-10.4 (show view - can be basic initially)
- UOW-13.1 through UOW-13.5 (dashboard widget)
- UOW-14.1, UOW-14.2 (navigation link)

**Demo Checkpoint**:
- User can create a savings goal
- User can see goal progress on goals index page
- Progress calculation is accurate
- User can edit and delete goals
- All tests pass
- (Stretch) Goals appear on dashboard

### Critical Path

The critical path for Sprint 1 is:
1. **Migration & Model** (Tasks T1, T2) - 4-5 hours
2. **Progress Calculations** (Task T3) - 2 hours
3. **Model Tests** (Task T4) - 3-4 hours
4. **Controller** (Task T5) - 3-4 hours
5. **Routes** (Task T6) - 10 minutes
6. **Form** (Task T7) - 4 hours
7. **Views** (Tasks T8, T9, T11) - 6-7 hours
8. **Controller Tests** (Task T12) - 4-5 hours

Total critical path: ~30-35 hours of focused work

**Buffer**: Additional 8-10 hours for bug fixes, edge cases, and polish

### Risks & Hidden Work

#### High Priority Risks

**Risk: Starting Balance Initialization**
- **What**: Determining the starting_balance for a goal when user creates it
- **Why it matters**: Progress calculation depends on accurate starting point
- **Phase/Epic**: EPIC-1 (Task T2, T3)
- **Mitigation**:
  - Set starting_balance = account.balance at goal creation time
  - Store this as a snapshot (don't recalculate dynamically)
  - Document this in model and tests
- **Impact if ignored**: Progress percentages will be wrong, user confusion

**Risk: Account Deletion with Linked Goals**
- **What**: What happens when user deletes an account that has active goals?
- **Why it matters**: Goals would become orphaned or show incorrect data
- **Phase/Epic**: EPIC-1 (UOW-2.2)
- **Mitigation**:
  - Option 1: Prevent account deletion if goals exist (add validation)
  - Option 2: Auto-archive goals when account deleted (preferred)
  - Option 3: Allow orphaned goals but handle gracefully in UI
  - **Decision**: Implement Option 2 - add before_destroy callback to Account that archives linked goals
- **Impact if ignored**: High - application errors, data inconsistency

**Risk: Negative Progress (Balance Decreases)**
- **What**: User's account balance goes down after creating goal
- **Why it matters**: Progress calculation returns negative values
- **Phase/Epic**: EPIC-1 (UOW-3.2, UOW-3.3)
- **Mitigation**:
  - Allow negative progress_amount (show reality)
  - Clamp completion_percentage to 0-100 range
  - Show visual indicator (red color) when progress is negative
  - Add "behind_schedule?" method to complement on_track?
- **Impact if ignored**: Medium - confusing UX but not breaking

**Risk: Currency Mismatch**
- **What**: Goal created in USD but linked to EUR account
- **Why it matters**: Progress calculations would be incorrect
- **Phase/Epic**: EPIC-1, EPIC-2
- **Mitigation**:
  - Force goal.currency = account.currency at creation
  - Add model validation: validate that goal.currency == account.currency
  - Disable currency field in form (auto-set via Stimulus)
- **Impact if ignored**: High - incorrect progress tracking

#### Medium Priority Risks

**Risk: Performance on Dashboard**
- **What**: Dashboard loads goals widget with N+1 queries
- **Why it matters**: Dashboard should load quickly (< 500ms)
- **Phase/Epic**: EPIC-3 (UOW-13.1)
- **Mitigation**:
  - Use includes(:account) when loading goals for dashboard
  - Limit to 5 goals maximum
  - Add database indexes on goals.family_id and goals.status
- **Impact if ignored**: Medium - slow dashboard load time

**Risk: Turbo Frame Integration**
- **What**: Goal forms may not work correctly in modal via Turbo Frames
- **Why it matters**: App uses Turbo Frames for modals (see new_account_path frame: :modal)
- **Phase/Epic**: EPIC-2 (Task T7)
- **Mitigation**:
  - Test form in modal context early
  - Ensure form redirects work with Turbo
  - May need to add data-turbo-frame attributes
- **Impact if ignored**: Medium - forms break in modal context

**Risk: Date Handling and Timezones**
- **What**: Target date comparison may be off due to timezone issues
- **Why it matters**: on_track? calculation uses date arithmetic
- **Phase/Epic**: EPIC-1 (UOW-3.5)
- **Mitigation**:
  - Use Date.current consistently (respects timezone)
  - Store target_date as date type (not datetime)
  - Test with dates in past, present, and future
- **Impact if ignored**: Low-Medium - slightly inaccurate tracking

#### Low Priority Risks

**Risk: Mobile UX for Goal Cards**
- **What**: Goal cards may not be responsive on small screens
- **Why it matters**: Users need mobile access
- **Phase/Epic**: EPIC-2 (Task T11), EPIC-3 (Task T13)
- **Mitigation**:
  - Use responsive Tailwind classes
  - Test on mobile viewport during development
  - Simplify card layout for mobile (stack elements vertically)
- **Impact if ignored**: Low - desktop works but mobile UX suffers

### Hidden Work (Often Forgotten)

1. **Error Handling**:
   - What if account.balance is nil? (UOW-3.1)
   - What if target_amount is zero? (UOW-3.3)
   - What if user enters past date as target_date? (add validation)
   - Estimated: 2 hours

2. **i18n Coverage**:
   - All user-facing strings need locale keys
   - Model attributes need i18n for form labels
   - Error messages need localization
   - Estimated: 2-3 hours (distributed across UOWs)

3. **Flash Messages**:
   - Success messages for create, update, destroy
   - Error messages for failed operations
   - Estimated: 1 hour (distributed across controller UOWs)

4. **Accessibility**:
   - Form labels and ARIA attributes
   - Keyboard navigation for goal cards
   - Screen reader support for progress bars
   - Estimated: 1-2 hours

5. **Database Indexes**:
   - Index on goals.family_id
   - Index on goals.account_id
   - Index on goals.status
   - Composite index on (family_id, status) for common query
   - Estimated: 30 minutes (in migration UOW-1.1)

6. **Migration Rollback**:
   - Ensure migration can be rolled back cleanly
   - Test with `bin/rails db:rollback`
   - Estimated: 15 minutes

7. **Empty States**:
   - Goals index when no goals exist
   - Dashboard widget when no goals (already handled by visibility)
   - Estimated: 30 minutes

8. **Confirmation Dialogs**:
   - Delete goal should show confirmation
   - Consider confirmation for editing target amount if goal is in progress
   - Estimated: 30 minutes

9. **Before Destroy Callbacks**:
   - Handle account deletion with linked goals
   - Consider what happens if family is deleted
   - Estimated: 1 hour

10. **Breadcrumbs**:
    - Set @breadcrumbs in each controller action
    - Follow existing pattern from other controllers
    - Estimated: 30 minutes

### Tech Debt Decisions

**Intentional Debt (Accepted for MVP Speed)**:

1. **Single Account Per Goal**:
   - **Why**: Multi-account goals add significant complexity
   - **When to address**: Phase 2 after validating user need
   - **Cost**: Requires schema change (join table), UI redesign

2. **No Goal Categories**:
   - **Why**: Categories add complexity to form and logic
   - **When to address**: Phase 2 once we see user patterns
   - **Cost**: Migration, UI updates, 1-2 days work

3. **Basic Progress Calculation**:
   - **Why**: Simple delta calculation (current - starting) is easy to understand and implement
   - **When to address**: Phase 2 with forecasting and savings rate
   - **Cost**: More sophisticated calculation (time-weighted, handling deposits/withdrawals separately)

4. **No Manual Contributions Tracking**:
   - **Why**: Relies on automatic balance sync, simpler data model
   - **When to address**: Phase 3-4 if users request it
   - **Cost**: New model (Goal Contributions), new UI, 3-4 days work

5. **No Budget Integration**:
   - **Why**: Budgets and goals are separate features, integration adds coupling
   - **When to address**: Phase 4 after both features mature
   - **Cost**: Complex business logic, 5-7 days work

**Unacceptable Debt (Must Fix Before Shipping)**:

1. No tests for core business logic
2. No error handling for deleted accounts
3. No validation for currency mismatch
4. N+1 queries on dashboard
5. Security issues (goals not scoped to family)

### Recommended Sequencing

**Day 1-2**: Foundation
- Complete EPIC-1 entirely (migration, model, calculations, tests)
- This unlocks all other work

**Day 3-5**: CRUD Interface
- Build controller and routes
- Build form and index view
- Create ViewComponent
- Write controller tests

**Day 6-7**: Dashboard Integration
- Add dashboard widget
- Add navigation link
- Polish and bug fixes

**Day 8-10**: Buffer
- Handle edge cases discovered during testing
- Improve error messages
- Mobile testing and fixes
- Final QA and documentation

### Definition of Done

Before marking Sprint 1 complete, verify:

- [ ] All UOWs in "Must-Have" list are completed
- [ ] All tests pass (`bin/rails test`)
- [ ] No RuboCop violations (`bin/rubocop -a`)
- [ ] No ERB lint violations (`bundle exec erb_lint ./app/**/*.erb -a`)
- [ ] No security issues (`bin/brakeman --no-pager`)
- [ ] Manual testing completed:
  - [ ] Create goal via form
  - [ ] View goal in index
  - [ ] Edit goal
  - [ ] Delete goal
  - [ ] View goal on dashboard
  - [ ] Test with account that has no goals
  - [ ] Test with deleted account
- [ ] i18n strings complete (no missing translations)
- [ ] Database migration runs and rolls back cleanly
- [ ] Documentation written:
  - [ ] `/docs/models/goal.md`
  - [ ] `/docs/ui/goal-components.md`
- [ ] Demo prepared for stakeholders

### Success Metrics

After Sprint 1 ships, measure:
- **Code Quality**: Test coverage > 90% for Goal model and controller
- **Performance**: Dashboard loads in < 500ms with goals widget
- **User Engagement**: % of users who create at least one goal in first week
- **UX Quality**: Zero "goals not loading" support tickets in first week

---

## F. Future Considerations (Post-Sprint 1)

### Phase 2 Features (Sprint 2)
- Goal categories and templates
- Multi-account goals
- Forecasting with savings rate calculation
- Goal detail page with progress chart over time
- Milestone celebrations (25%, 50%, 75%, 100%)

### Phase 3 Features (Sprint 3)
- AI assistant integration (get_goals, create_goal, update_goal functions)
- AI-powered goal suggestions
- Natural language goal queries

### Phase 4 Features (Sprint 4)
- Budget integration (allocate surplus to goals)
- Goal prioritization
- What-if scenarios
- Mobile app optimization
- Performance tuning

### Possible v2 Features (Future Sprints)
- Recurring contribution tracking
- Goal sharing with family members
- Investment goal tracking (separate from savings goals)
- Goal activity feed/history
- Social features (compare with anonymous peers)
- Gamification (badges, streaks, achievements)

---

## Summary

This epic delivers a complete MVP for Goals & Savings Tracking in Sprint 1:
- Users can create, view, edit, and delete savings goals
- Goals track progress based on account balance changes
- Dashboard prominently displays goals to maintain focus
- Foundation is solid for advanced features in future sprints

The implementation follows all project conventions:
- Rails-first architecture (models > services)
- Hotwire for interactivity
- Design system components
- Comprehensive test coverage
- i18n throughout

Risks are identified and mitigated, with clear decision points documented.
