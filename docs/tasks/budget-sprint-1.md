# Sprint 1: Budget Intelligence Dashboard MVP

## Sprint Goal
Deliver a functional budget intelligence dashboard with real-time progress tracking, category-level pace indicators, and basic alert system. Users with active budgets can see their spending progress, receive warnings when approaching limits, and understand if they're "on pace" to meet their budget.

## Sprint Duration
**2 weeks** (10 working days)

## Success Criteria
- [ ] Budget dashboard accessible and displays real-time progress
- [ ] Category-level tracking shows pace indicators (on track / ahead / behind)
- [ ] Basic alerts system warns users at 90% and 100% thresholds
- [ ] All existing budget functionality works unchanged
- [ ] Tests pass, no regressions
- [ ] i18n complete for new strings

---

# Task Breakdown

## TASK T1: Budget Projection & Pacing Calculations

**Priority**: Critical
**Estimated Effort**: Large (1.5 days)
**Belongs to**: Budget Intelligence Dashboard MVP
**Blocked by**: None

### Description
Add calculation methods to Budget and BudgetCategory models to support projection and pacing logic. These methods will determine if spending is "on track", project end-of-month totals, and calculate recommended daily spending.

### Acceptance Criteria
- [ ] `Budget#projected_month_end_spending` calculates estimated total spending by month end based on current pace
- [ ] `Budget#days_remaining_in_period` returns count of days left in budget period
- [ ] `Budget#spending_pace_status` returns `:on_track`, `:ahead_of_pace`, or `:behind_pace`
- [ ] `BudgetCategory#projected_month_end_spending` calculates category-specific projections
- [ ] `BudgetCategory#pace_status` returns category-specific pace indicator
- [ ] `BudgetCategory#recommended_daily_spending_updated` refines existing method with better edge case handling
- [ ] All calculations handle edge cases: first/last day of month, zero budgets, no spending yet
- [ ] Calculations use existing `Period` helpers and monetization
- [ ] Methods are cached appropriately (leverage `entries_cache_version`)

### Units of Work (UOWs)

#### UOW U1.1: Add Budget Projection Methods
- **Type**: backend
- **Exact Action**: Add instance methods to `Budget` model for month-end projections and pace calculations
- **Estimate**: 2 hours
- **Dependencies**: None
- **Files Modified**:
  - `/Users/Cody/code_projects/sure/app/models/budget.rb`
- **Acceptance Checks**:
  - `Budget#projected_month_end_spending` returns Money object representing linear projection
  - `Budget#days_remaining_in_period` returns integer (1-31 depending on date)
  - `Budget#spending_pace_status` returns symbol (`:on_track`, `:ahead_of_pace`, `:behind_pace`)
  - Logic accounts for partial months and edge cases
  - Uses existing `period` and `actual_spending` methods

#### UOW U1.2: Add BudgetCategory Projection Methods
- **Type**: backend
- **Exact Action**: Add instance methods to `BudgetCategory` model for category-specific pacing and projections
- **Estimate**: 2 hours
- **Dependencies**: U1.1 (similar patterns)
- **Files Modified**:
  - `/Users/Cody/code_projects/sure/app/models/budget_category.rb`
- **Acceptance Checks**:
  - `BudgetCategory#projected_month_end_spending` calculates category projection
  - `BudgetCategory#pace_status` returns `:on_track`, `:ahead_of_pace`, `:behind_pace`, `:no_budget`
  - `BudgetCategory#days_ahead_or_behind` returns integer representing pace differential
  - Reuses parent `budget.days_remaining_in_period`
  - Handles zero-budget categories gracefully (tracking-only mode)

#### UOW U1.3: Write Model Tests for Projections
- **Type**: tests
- **Exact Action**: Add comprehensive Minitest unit tests for new projection methods
- **Estimate**: 3 hours
- **Dependencies**: U1.1, U1.2
- **Files Modified**:
  - `/Users/Cody/code_projects/sure/test/models/budget_test.rb`
  - `/Users/Cody/code_projects/sure/test/fixtures/budgets.yml` (if new fixtures needed)
- **Acceptance Checks**:
  - Test edge cases: first day of month, last day, mid-month
  - Test zero spending, zero budget, exact budget match
  - Test partial month scenarios
  - Test pace status transitions (on track → ahead → behind)
  - Test with existing fixtures (avoid creating many new fixtures)
  - All tests pass

#### UOW U1.4: Add i18n Keys for Pace Indicators
- **Type**: docs
- **Exact Action**: Add internationalization keys for pace status labels and descriptions
- **Estimate**: 30 minutes
- **Dependencies**: None
- **Files Modified**:
  - `/Users/Cody/code_projects/sure/config/locales/en.yml`
- **Acceptance Checks**:
  - Keys added under `budgets.pace_status.*`
  - Includes: `on_track`, `ahead_of_pace`, `behind_pace`, `no_data`
  - Includes descriptions for tooltips/help text
  - Follows existing i18n structure and naming conventions

---

## TASK T2: Budget Alert Detection System

**Priority**: Critical
**Estimated Effort**: Medium (1 day)
**Belongs to**: Budget Intelligence Dashboard MVP
**Blocked by**: T1 (uses projection methods)

### Description
Implement alert detection logic to identify when budgets are approaching or exceeding limits. Alerts will be calculated on-demand (no persistence in MVP) and displayed in the dashboard view.

### Acceptance Criteria
- [ ] `Budget#alerts` method returns array of alert hashes for overall budget
- [ ] `BudgetCategory#alerts` method returns array of alert hashes for category
- [ ] Alert types supported: `:approaching_limit` (90%), `:exceeded` (100%), `:pace_warning` (projected overage)
- [ ] Each alert includes: `type`, `severity`, `category` (if applicable), `message`, `amount_over`, `recommended_action`
- [ ] Alerts are sorted by severity: exceeded > pace_warning > approaching
- [ ] Alert thresholds are configurable via constants (easy to adjust later)
- [ ] No database persistence in MVP (calculated on each page load)

### Units of Work (UOWs)

#### UOW U2.1: Create BudgetAlert Value Object
- **Type**: backend
- **Exact Action**: Create a simple value object class to represent budget alerts
- **Estimate**: 1 hour
- **Dependencies**: None
- **Files Created**:
  - `/Users/Cody/code_projects/sure/app/models/budget_alert.rb`
- **Acceptance Checks**:
  - `BudgetAlert` is a `Data.define` or simple Ruby class (not ActiveRecord)
  - Attributes: `:type`, `:severity`, `:category`, `:message`, `:amount`, `:recommended_action`
  - Severity levels: `:info`, `:warning`, `:critical`
  - Provides `#to_h` method for easy JSON serialization
  - Includes comparison method for sorting by severity

#### UOW U2.2: Add Alert Detection to Budget Model
- **Type**: backend
- **Exact Action**: Implement `Budget#alerts` method to detect budget-level alerts
- **Estimate**: 2 hours
- **Dependencies**: U2.1, T1 (projection methods)
- **Files Modified**:
  - `/Users/Cody/code_projects/sure/app/models/budget.rb`
- **Acceptance Checks**:
  - `Budget#alerts` returns array of `BudgetAlert` objects
  - Detects when `percent_of_budget_spent >= 90` (approaching limit)
  - Detects when `percent_of_budget_spent >= 100` (exceeded)
  - Detects when `projected_month_end_spending > budgeted_spending` (pace warning)
  - Includes helpful messages with amounts and recommended actions
  - Returns empty array if no alerts triggered
  - Thresholds defined as class constants (`APPROACHING_THRESHOLD = 90`)

#### UOW U2.3: Add Alert Detection to BudgetCategory Model
- **Type**: backend
- **Exact Action**: Implement `BudgetCategory#alerts` method for category-specific alerts
- **Estimate**: 2 hours
- **Dependencies**: U2.1, U2.2 (similar pattern)
- **Files Modified**:
  - `/Users/Cody/code_projects/sure/app/models/budget_category.rb`
- **Acceptance Checks**:
  - `BudgetCategory#alerts` returns array of `BudgetAlert` objects
  - Detects same thresholds as Budget (90%, 100%, projected overage)
  - Alert messages include category name and icon reference
  - Recommended actions are category-specific (e.g., "Reduce dining spending to $X/day")
  - Handles zero-budget categories (no alerts)
  - Handles subcategories correctly (alerts on subcategory, not rolled up)

#### UOW U2.4: Write Alert Detection Tests
- **Type**: tests
- **Exact Action**: Add Minitest tests for alert detection logic
- **Estimate**: 2 hours
- **Dependencies**: U2.2, U2.3
- **Files Modified**:
  - `/Users/Cody/code_projects/sure/test/models/budget_test.rb`
  - `/Users/Cody/code_projects/sure/test/models/budget_category_test.rb`
- **Acceptance Checks**:
  - Test no alerts when spending is low (<90%)
  - Test approaching alert at exactly 90%
  - Test exceeded alert at 100% and above
  - Test pace warning when projection exceeds budget
  - Test alert priority/sorting
  - Test edge cases: zero budget, no spending, first day of month
  - All tests use existing fixtures where possible

#### UOW U2.5: Add i18n Keys for Alerts
- **Type**: docs
- **Exact Action**: Add internationalization keys for alert messages and actions
- **Estimate**: 30 minutes
- **Dependencies**: None
- **Files Modified**:
  - `/Users/Cody/code_projects/sure/config/locales/en.yml`
- **Acceptance Checks**:
  - Keys added under `budgets.alerts.*`
  - Includes alert type labels: `approaching_limit`, `exceeded`, `pace_warning`
  - Includes message templates with interpolation: `%{category}`, `%{amount}`, `%{percentage}`
  - Includes recommended action templates
  - Follows existing i18n structure

---

## TASK T3: Budget Dashboard Controller & Routing

**Priority**: Critical
**Estimated Effort**: Small (0.5 day)
**Belongs to**: Budget Intelligence Dashboard MVP
**Blocked by**: T1, T2 (uses projection and alert methods)

### Description
Extend the BudgetsController to include a dashboard action that loads all necessary data for the intelligence view. Update routing to make dashboard the default budget view.

### Acceptance Criteria
- [ ] `BudgetsController#show` loads dashboard data instead of simple show view
- [ ] Dashboard action fetches: current budget, all categories with projections, alerts, previous month comparison
- [ ] Previous month budget loaded for trend comparison
- [ ] All data pre-loaded to avoid N+1 queries (use `includes`)
- [ ] Route `/budgets/:month_year` displays dashboard by default
- [ ] Existing edit route `/budgets/:month_year/edit` remains unchanged
- [ ] Authorization checks ensure user can only view their family's budgets

### Units of Work (UOWs)

#### UOW U3.1: Refactor BudgetsController#show for Dashboard
- **Type**: backend
- **Exact Action**: Update `show` action to load additional dashboard data
- **Estimate**: 1.5 hours
- **Dependencies**: T1, T2
- **Files Modified**:
  - `/Users/Cody/code_projects/sure/app/controllers/budgets_controller.rb`
- **Acceptance Checks**:
  - `@budget` loaded with `includes(:budget_categories)` to avoid N+1
  - `@alerts` calculated once and stored in instance variable
  - `@category_alerts` grouped by category for easy rendering
  - `@previous_budget` loaded for comparison (previous month)
  - `@projection_data` prepared for charts/visualizations
  - No N+1 queries (verify with bullet gem or query log)
  - Existing functionality preserved (edit still works)

#### UOW U3.2: Add Dashboard Helper Methods
- **Type**: backend
- **Exact Action**: Create helper methods for formatting dashboard data
- **Estimate**: 1 hour
- **Dependencies**: None
- **Files Modified**:
  - `/Users/Cody/code_projects/sure/app/helpers/budgets_helper.rb` (or create if doesn't exist)
- **Acceptance Checks**:
  - `pace_status_badge(status)` returns HTML for status badge with color
  - `alert_severity_class(severity)` returns CSS class for alert styling
  - `budget_progress_percentage(budget_category)` returns formatted percentage
  - `days_remaining_text(budget)` returns human-readable text like "15 days left"
  - Helpers use existing design system classes
  - All helpers return HTML-safe strings

#### UOW U3.3: Write Controller Tests
- **Type**: tests
- **Exact Action**: Add/update controller tests for dashboard action
- **Estimate**: 1.5 hours
- **Dependencies**: U3.1
- **Files Modified**:
  - `/Users/Cody/code_projects/sure/test/controllers/budgets_controller_test.rb`
- **Acceptance Checks**:
  - Test dashboard loads successfully for current month budget
  - Test dashboard loads for past month budgets
  - Test dashboard redirects if budget date is invalid
  - Test authorization (user can't view other family's budgets)
  - Test instance variables are set correctly
  - Test no N+1 queries (use `assert_queries` or bullet)
  - Existing tests still pass

---

## TASK T4: Budget Dashboard View Components

**Priority**: Critical
**Estimated Effort**: Large (2 days)
**Belongs to**: Budget Intelligence Dashboard MVP
**Blocked by**: T3 (needs controller data)

### Description
Build the visual dashboard interface using existing design system components and Hotwire patterns. Create reusable view components for alerts, progress indicators, and category cards.

### Acceptance Criteria
- [ ] Dashboard displays overall budget summary (total budgeted, spent, remaining, % used)
- [ ] Visual progress bar shows overall spending progress with color coding
- [ ] Alert banner displays active alerts at top of dashboard
- [ ] Category breakdown shows each budget category as a card with:
  - Category name, icon, color
  - Progress bar (% of budget used)
  - Pace indicator badge (on track / ahead / behind)
  - Amounts: budgeted, actual, remaining
  - Recommended daily spending (if applicable)
- [ ] Categories sorted by "at risk" status (exceeded > near limit > on track)
- [ ] "Compared to last month" section shows key differences
- [ ] Mobile responsive (stacks vertically on small screens)
- [ ] Uses existing design system components (DS::Alert, DS::Badge, etc.)
- [ ] All text uses i18n keys

### Units of Work (UOWs)

#### UOW U4.1: Create Alert Banner Component
- **Type**: frontend
- **Exact Action**: Build a ViewComponent for displaying budget alerts
- **Estimate**: 2 hours
- **Dependencies**: T2 (alert data)
- **Files Created**:
  - `/Users/Cody/code_projects/sure/app/components/budget/alert_banner.rb`
  - `/Users/Cody/code_projects/sure/app/components/budget/alert_banner.html.erb`
- **Files Modified**:
  - `/Users/Cody/code_projects/sure/test/components/previews/budget_alert_banner_preview.rb` (Lookbook preview)
- **Acceptance Checks**:
  - Component accepts array of `BudgetAlert` objects
  - Renders up to 3 most severe alerts (hide rest behind "Show more")
  - Uses `DS::Alert` component for styling
  - Color codes by severity: info (blue), warning (yellow), critical (red)
  - Includes dismiss button (stores dismissal in session for current page load)
  - Shows icon appropriate to alert type
  - Mobile responsive (full width, readable text)
  - i18n for all strings

#### UOW U4.2: Create Budget Progress Card Component
- **Type**: frontend
- **Exact Action**: Build ViewComponent for overall budget progress summary
- **Estimate**: 2 hours
- **Dependencies**: None
- **Files Created**:
  - `/Users/Cody/code_projects/sure/app/components/budget/progress_card.rb`
  - `/Users/Cody/code_projects/sure/app/components/budget/progress_card.html.erb`
- **Files Modified**:
  - `/Users/Cody/code_projects/sure/test/components/previews/budget_progress_card_preview.rb`
- **Acceptance Checks**:
  - Displays: budgeted amount, actual spending, remaining, % used
  - Visual progress bar (reuse existing budget bar styling)
  - Color codes: green (<75%), yellow (75-100%), red (>100%)
  - Shows "Days remaining: X" subtitle
  - Shows projected month-end spending if pace warning exists
  - Responsive layout (horizontal on desktop, vertical on mobile)
  - Uses existing `bg-container`, `shadow-border-xs` design system classes

#### UOW U4.3: Create Category Progress Card Component
- **Type**: frontend
- **Exact Action**: Build ViewComponent for individual budget category cards
- **Estimate**: 3 hours
- **Dependencies**: None
- **Files Created**:
  - `/Users/Cody/code_projects/sure/app/components/budget/category_card.rb`
  - `/Users/Cody/code_projects/sure/app/components/budget/category_card.html.erb`
- **Files Modified**:
  - `/Users/Cody/code_projects/sure/test/components/previews/budget_category_card_preview.rb`
- **Acceptance Checks**:
  - Displays category icon (using `icon` helper), name, color swatch
  - Progress bar showing % of budget used
  - Pace status badge ("On Track", "Ahead of Pace", "Behind Pace")
  - Amounts: budgeted, actual spent, remaining (formatted as Money)
  - Recommended daily spending (if available and budget > 0)
  - Link to view transactions in this category
  - Alert indicator if category has alerts
  - Handles zero-budget categories (shows "Tracking only")
  - Mobile responsive (full width cards on mobile)
  - Uses `bg-container`, `rounded-xl`, `shadow-border-xs`

#### UOW U4.4: Update Budget Show View to Use Dashboard Components
- **Type**: frontend
- **Exact Action**: Refactor `/app/views/budgets/show.html.erb` to render new dashboard layout
- **Estimate**: 2 hours
- **Dependencies**: U4.1, U4.2, U4.3
- **Files Modified**:
  - `/Users/Cody/code_projects/sure/app/views/budgets/show.html.erb`
- **Acceptance Checks**:
  - Alert banner rendered at top (if alerts present)
  - Progress card rendered in grid layout
  - Category cards rendered in responsive grid (2-3 columns desktop, 1 column mobile)
  - Categories sorted by alert status, then by name
  - Previous month comparison section (simple stats for now)
  - Existing budget header/nav preserved
  - No layout shifts or visual regressions
  - Fast render time (<100ms for typical budget)

#### UOW U4.5: Add Stimulus Controller for Alert Dismissal
- **Type**: frontend
- **Exact Action**: Create Stimulus controller to handle alert banner dismissal
- **Estimate**: 1 hour
- **Dependencies**: U4.1
- **Files Created**:
  - `/Users/Cody/code_projects/sure/app/components/budget/alert_banner_controller.js` (co-located with component)
- **Acceptance Checks**:
  - Controller connected to alert banner component
  - Dismiss button hides alert with smooth transition
  - Dismissal persists for current page session (stores in sessionStorage)
  - Re-appears on page refresh (no backend persistence in MVP)
  - Follows existing Stimulus controller patterns
  - Handles multiple alerts independently

#### UOW U4.6: Add i18n Keys for Dashboard UI
- **Type**: docs
- **Exact Action**: Add all internationalization keys for dashboard view text
- **Estimate**: 1 hour
- **Dependencies**: U4.1-U4.5
- **Files Modified**:
  - `/Users/Cody/code_projects/sure/config/locales/en.yml`
- **Acceptance Checks**:
  - Keys added under `budgets.dashboard.*`
  - Includes: section headings, labels, tooltips, help text
  - Includes progress card labels: "Budgeted", "Spent", "Remaining", "Days left"
  - Includes category card labels: "On track", "Ahead of pace", "Behind pace"
  - Includes alert banner text templates
  - All interpolation variables documented
  - Follows existing i18n structure

---

## TASK T5: Previous Month Comparison

**Priority**: Medium
**Estimated Effort**: Small (0.5 day)
**Belongs to**: Budget Intelligence Dashboard MVP
**Blocked by**: T3 (needs controller loading previous budget)

### Description
Add a simple comparison section showing how current month compares to previous month's budget performance. Provides context for whether user is improving or regressing.

### Acceptance Criteria
- [ ] Dashboard displays "Compared to Last Month" section
- [ ] Shows: spending difference ($ and %), pace difference, alert count change
- [ ] Uses up/down arrows and color coding (green for improvement, red for regression)
- [ ] Handles edge case: no previous month budget exists (hide section)
- [ ] Comparison is simple stats only (no detailed breakdown in MVP)
- [ ] Mobile responsive layout

### Units of Work (UOWs)

#### UOW U5.1: Add Comparison Calculation Methods
- **Type**: backend
- **Exact Action**: Add methods to Budget model for calculating month-over-month changes
- **Estimate**: 1 hour
- **Dependencies**: None
- **Files Modified**:
  - `/Users/Cody/code_projects/sure/app/models/budget.rb`
- **Acceptance Checks**:
  - `Budget#spending_change_from(previous_budget)` returns Money difference
  - `Budget#spending_change_percentage_from(previous_budget)` returns percentage
  - `Budget#pace_improvement_from(previous_budget)` returns boolean
  - Methods handle nil previous_budget gracefully (return nil or 0)
  - Uses existing `actual_spending` and comparison logic

#### UOW U5.2: Create Comparison Section Component
- **Type**: frontend
- **Exact Action**: Build ViewComponent for month-over-month comparison display
- **Estimate**: 2 hours
- **Dependencies**: U5.1
- **Files Created**:
  - `/Users/Cody/code_projects/sure/app/components/budget/comparison_section.rb`
  - `/Users/Cody/code_projects/sure/app/components/budget/comparison_section.html.erb`
- **Acceptance Checks**:
  - Accepts current budget and previous budget as props
  - Displays spending change with up/down arrow icon
  - Green background for spending decrease, red for increase
  - Shows percentage change alongside dollar amount
  - Shows simple text: "You spent $X more/less than last month"
  - Hides entire section if no previous budget exists
  - Uses existing design system spacing and typography
  - Mobile responsive

#### UOW U5.3: Integrate Comparison into Dashboard View
- **Type**: frontend
- **Exact Action**: Add comparison section to budget show view
- **Estimate**: 30 minutes
- **Dependencies**: U5.2
- **Files Modified**:
  - `/Users/Cody/code_projects/sure/app/views/budgets/show.html.erb`
- **Acceptance Checks**:
  - Comparison section rendered below progress card, above category grid
  - Only renders if `@previous_budget` exists
  - Positioned appropriately in responsive layout
  - No visual regressions

#### UOW U5.4: Add i18n Keys for Comparison
- **Type**: docs
- **Exact Action**: Add internationalization keys for comparison section
- **Estimate**: 15 minutes
- **Dependencies**: None
- **Files Modified**:
  - `/Users/Cody/code_projects/sure/config/locales/en.yml`
- **Acceptance Checks**:
  - Keys under `budgets.comparison.*`
  - Includes: "Compared to Last Month", "more than", "less than", "same as"
  - Supports interpolation for amounts and percentages

---

## TASK T6: Budget Recommendations (AI-Powered)

**Priority**: Low (Nice-to-Have)
**Estimated Effort**: Medium (1 day)
**Belongs to**: Budget Intelligence Dashboard MVP
**Blocked by**: None (can be built independently)

### Description
Provide AI-powered budget recommendations based on historical spending patterns. Helps users set realistic budgets when creating or editing allocations.

### Acceptance Criteria
- [ ] When editing budget categories, each category shows "Suggested: $X" based on historical median
- [ ] Recommendation based on 3-month median by default
- [ ] User can click "Use suggestion" to auto-fill the amount
- [ ] Recommendation shows data source (e.g., "Based on last 3 months")
- [ ] Handles categories with insufficient data gracefully ("Not enough data")
- [ ] Works for both new budgets and existing budget edits
- [ ] Does not interfere with manual budget entry

### Units of Work (UOWs)

#### UOW U6.1: Add Recommendation Calculation Methods
- **Type**: backend
- **Exact Action**: Add methods to BudgetCategory for calculating recommended budgets
- **Estimate**: 2 hours
- **Dependencies**: None (uses existing IncomeStatement methods)
- **Files Modified**:
  - `/Users/Cody/code_projects/sure/app/models/budget_category.rb`
- **Acceptance Checks**:
  - `BudgetCategory#recommended_budget(lookback_months: 3)` returns Money suggestion
  - Uses `budget.category_median_monthly_expense(category)` from existing IncomeStatement
  - Returns nil if insufficient data (< 2 months of transactions in category)
  - Supports configurable lookback period (3, 6, 12 months)
  - Recommendation is based on median, not average (more robust to outliers)

#### UOW U6.2: Update Budget Category Edit View with Recommendations
- **Type**: frontend
- **Exact Action**: Add recommendation display to budget category allocation form
- **Estimate**: 2 hours
- **Dependencies**: U6.1
- **Files Modified**:
  - `/Users/Cody/code_projects/sure/app/views/budget_categories/_form.html.erb` (or similar)
  - `/Users/Cody/code_projects/sure/app/controllers/budget_categories_controller.rb` (load recommendations)
- **Acceptance Checks**:
  - Each category input field shows "Suggested: $X" below or beside it
  - "Use suggestion" button auto-fills the input with recommended amount
  - Shows "Based on last 3 months" subtitle
  - Shows "Not enough data" if recommendation is nil
  - Does not auto-fill without user action
  - Recommendation updates if user changes lookback period (future: dropdown for 3/6/12 months)
  - Mobile responsive

#### UOW U6.3: Add Stimulus Controller for Auto-Fill
- **Type**: frontend
- **Exact Action**: Create Stimulus controller to handle "Use suggestion" button clicks
- **Estimate**: 1 hour
- **Dependencies**: U6.2
- **Files Created**:
  - `/Users/Cody/code_projects/sure/app/javascript/controllers/budget_recommendation_controller.js`
- **Acceptance Checks**:
  - Controller connected to recommendation elements
  - Click "Use suggestion" fills input field with recommended amount
  - Preserves user's manual edits (doesn't override unless clicked)
  - Works for all categories independently
  - Smooth UX (no page reload)

#### UOW U6.4: Add i18n Keys for Recommendations
- **Type**: docs
- **Exact Action**: Add internationalization keys for recommendation UI
- **Estimate**: 15 minutes
- **Dependencies**: None
- **Files Modified**:
  - `/Users/Cody/code_projects/sure/config/locales/en.yml`
- **Acceptance Checks**:
  - Keys under `budgets.recommendations.*`
  - Includes: "Suggested", "Use suggestion", "Based on last X months", "Not enough data"
  - Supports interpolation for amounts and periods

---

## TASK T7: Integration Testing & Bug Fixes

**Priority**: Critical
**Estimated Effort**: Medium (1 day)
**Belongs to**: Budget Intelligence Dashboard MVP
**Blocked by**: T1-T6 (all features complete)

### Description
Comprehensive integration testing of the full budget intelligence dashboard. Identify and fix bugs, edge cases, and performance issues before launch.

### Acceptance Criteria
- [ ] All unit tests pass
- [ ] Integration tests cover critical user flows
- [ ] No N+1 queries detected (use bullet gem)
- [ ] Dashboard loads in <2 seconds for typical budget (20 categories)
- [ ] All i18n keys have translations (no missing key warnings)
- [ ] Mobile responsive on iPhone SE (smallest target screen)
- [ ] No console errors or warnings
- [ ] No visual regressions in existing budget views

### Units of Work (UOWs)

#### UOW U7.1: Write Integration Tests
- **Type**: tests
- **Exact Action**: Add controller/integration tests for complete dashboard flow
- **Estimate**: 3 hours
- **Dependencies**: All previous UOWs
- **Files Modified**:
  - `/Users/Cody/code_projects/sure/test/controllers/budgets_controller_test.rb`
  - `/Users/Cody/code_projects/sure/test/integration/budget_dashboard_test.rb` (create if needed)
- **Acceptance Checks**:
  - Test: User with active budget sees dashboard
  - Test: User with over-budget category sees alert
  - Test: User with no previous budget doesn't see comparison
  - Test: Categories sorted correctly by alert status
  - Test: Recommendations appear in edit view
  - Test: Mobile viewport renders correctly
  - All assertions pass

#### UOW U7.2: Performance Audit & Optimization
- **Type**: backend
- **Exact Action**: Identify and fix N+1 queries, slow calculations, and rendering bottlenecks
- **Estimate**: 2 hours
- **Dependencies**: U7.1 (tests reveal issues)
- **Files Modified**: Various (as needed based on audit findings)
- **Acceptance Checks**:
  - Bullet gem reports no N+1 queries in dashboard action
  - Dashboard page load time <2 seconds (measured with Rails logs)
  - Category cards render time <100ms total
  - Alert calculations cached appropriately
  - Database query count <20 for typical dashboard load
  - No slow queries (all <100ms)

#### UOW U7.3: i18n Completeness Check
- **Type**: docs
- **Exact Action**: Audit all new UI for missing i18n keys and add translations
- **Estimate**: 1 hour
- **Dependencies**: All UI UOWs complete
- **Files Modified**:
  - `/Users/Cody/code_projects/sure/config/locales/en.yml`
- **Acceptance Checks**:
  - Run app in development and check for "translation missing" warnings
  - All user-facing strings use `t()` helper, not hardcoded text
  - All keys follow existing naming conventions
  - Placeholder/example text removed from production code

#### UOW U7.4: Manual QA Checklist
- **Type**: tests
- **Exact Action**: Perform manual testing on local development environment
- **Estimate**: 2 hours
- **Dependencies**: All other UOWs complete
- **Acceptance Checks**:
  - [ ] Dashboard loads successfully for current month
  - [ ] Dashboard loads for past months
  - [ ] Alerts appear at correct thresholds (manually adjust budget to test)
  - [ ] Pace indicators update correctly as days pass (test with different dates)
  - [ ] Recommendations appear in edit view
  - [ ] "Use suggestion" button works
  - [ ] Comparison section shows when previous month exists
  - [ ] Mobile layout works on iPhone SE simulator
  - [ ] No console errors in browser
  - [ ] All links work correctly
  - [ ] Existing budget functionality unchanged (edit, allocate, donut chart)

---

## TASK T8: Documentation & Deployment Prep

**Priority**: Medium
**Estimated Effort**: Small (0.5 day)
**Belongs to**: Budget Intelligence Dashboard MVP
**Blocked by**: T7 (all features tested and working)

### Description
Prepare documentation, update README, and ensure smooth deployment of the budget intelligence dashboard feature.

### Acceptance Criteria
- [ ] README updated with new budget dashboard feature
- [ ] Code comments added to complex calculations
- [ ] Migration guide written (if any DB changes needed)
- [ ] Changelog updated with feature summary
- [ ] PR description template filled out completely

### Units of Work (UOWs)

#### UOW U8.1: Add Code Documentation
- **Type**: docs
- **Exact Action**: Add clear comments to complex budget calculation methods
- **Estimate**: 1 hour
- **Dependencies**: None
- **Files Modified**:
  - `/Users/Cody/code_projects/sure/app/models/budget.rb`
  - `/Users/Cody/code_projects/sure/app/models/budget_category.rb`
  - `/Users/Cody/code_projects/sure/app/models/budget_alert.rb`
- **Acceptance Checks**:
  - All projection methods have docstring comments explaining algorithm
  - Alert threshold constants have explanatory comments
  - Complex edge case handling is documented inline
  - Example usage shown in comments where helpful
  - Follows existing code comment style in codebase

#### UOW U8.2: Update README and Changelog
- **Type**: docs
- **Exact Action**: Document new budget intelligence dashboard feature
- **Estimate**: 1 hour
- **Dependencies**: None
- **Files Modified**:
  - `/Users/Cody/code_projects/sure/README.md`
  - `/Users/Cody/code_projects/sure/CHANGELOG.md` (if exists)
- **Acceptance Checks**:
  - README feature list includes "Budget Intelligence Dashboard"
  - Brief description of key capabilities (projections, alerts, recommendations)
  - Screenshots or GIF added (optional for MVP)
  - Changelog entry summarizes changes with proper versioning
  - Credits contributors if applicable

#### UOW U8.3: Create Pull Request
- **Type**: docs
- **Exact Action**: Open PR with comprehensive description and testing notes
- **Estimate**: 30 minutes
- **Dependencies**: All code complete
- **Files Modified**: N/A (GitHub PR)
- **Acceptance Checks**:
  - PR title: "Feature: Budget Intelligence Dashboard with Real-Time Tracking"
  - Description includes: feature summary, user stories addressed, technical approach
  - Testing checklist included (from U7.4)
  - Screenshots of dashboard before/after
  - Breaking changes section (none expected)
  - Reviewer guidance on how to test locally
  - Links to epic and task documents

---

## Sprint Schedule & Dependencies

### Week 1 (Days 1-5)
**Day 1:**
- T1: Budget Projection & Pacing Calculations (U1.1-U1.4) - **CRITICAL PATH**

**Day 2:**
- T2: Budget Alert Detection System (U2.1-U2.5) - **CRITICAL PATH**

**Day 3:**
- T3: Budget Dashboard Controller & Routing (U3.1-U3.3) - **CRITICAL PATH**
- T5: Previous Month Comparison (U5.1-U5.2) - Parallel to T3

**Day 4:**
- T4: Budget Dashboard View Components (U4.1-U4.3) - **CRITICAL PATH**

**Day 5:**
- T4: Budget Dashboard View Components (U4.4-U4.6) - **CRITICAL PATH**

### Week 2 (Days 6-10)
**Day 6:**
- T5: Previous Month Comparison (U5.3-U5.4) - Complete
- T6: Budget Recommendations (U6.1-U6.2) - Nice-to-have, can descope if needed

**Day 7:**
- T6: Budget Recommendations (U6.3-U6.4) - Complete
- T7: Integration Testing (U7.1) - Begin testing

**Day 8:**
- T7: Integration Testing & Bug Fixes (U7.2-U7.4) - **CRITICAL PATH**

**Day 9:**
- T7: Bug fixes and polish
- T8: Documentation (U8.1-U8.2)

**Day 10:**
- Final QA, PR creation, handoff

### Critical Path (Must Complete for MVP)
1. T1 → T2 → T3 → T4 → T7 → T8

### Parallel Tracks
- T5 (Comparison) can be built alongside T3/T4
- T6 (Recommendations) is nice-to-have, can be descoped if sprint runs over

### Descope Options (if needed)
1. **First to cut**: T6 (Budget Recommendations) - move to Sprint 2
2. **Second to cut**: T5 (Previous Month Comparison) - move to Sprint 2
3. **Minimum viable**: T1 + T2 + T3 + T4 + T7 (core dashboard + alerts only)

---

## Definition of Done (Sprint Level)

- [ ] All critical path tasks (T1-T4, T7) complete
- [ ] All unit tests pass (`bin/rails test`)
- [ ] No Rubocop violations (`bin/rubocop -f github`)
- [ ] No ERB linting errors (`bundle exec erb_lint ./app/**/*.erb`)
- [ ] No security issues (`bin/brakeman --no-pager`)
- [ ] Dashboard viewable at `/budgets/:month_year`
- [ ] At least 3 alert types functional (approaching, exceeded, pace)
- [ ] Mobile responsive on iPhone SE
- [ ] i18n complete (no missing translation warnings)
- [ ] Code reviewed and approved
- [ ] PR merged to main branch

---

## Risk Mitigation

### Risk: Sprint Overruns
- **Mitigation**: Clearly defined descope options (T5, T6)
- **Backup Plan**: Ship minimum viable dashboard (T1-T4 only), add features in Sprint 2

### Risk: Performance Issues with Large Budgets
- **Mitigation**: U7.2 dedicated to performance optimization
- **Backup Plan**: Add pagination for category cards if >30 categories

### Risk: Calculation Bugs in Projections
- **Mitigation**: Comprehensive tests in U1.3, U2.4
- **Backup Plan**: Roll back projection feature if major bugs, ship alerts only

### Risk: UI/UX Not Matching Existing Design System
- **Mitigation**: Reuse existing components (DS::Alert, DS::Badge, etc.)
- **Backup Plan**: Request design review in mid-sprint checkpoint (Day 5)

---

## Success Metrics (Post-Launch)

Track these metrics 2 weeks after launch:

- **Adoption**: % of users with active budgets who view dashboard (Target: 60%+)
- **Engagement**: Average dashboard views per week (Target: 2+)
- **Effectiveness**: % reduction in budget overruns month-over-month (Target: 20%+)
- **Performance**: P95 dashboard load time (Target: <2 seconds)
- **Quality**: Bug reports related to budget intelligence (Target: <5 in first 2 weeks)

---

## Notes & Assumptions

- Assumes existing budget infrastructure is stable (Budget, BudgetCategory models)
- Assumes sufficient transaction data for meaningful insights (users with 2+ months)
- Assumes design system components (DS::Alert, DS::Badge) meet needs
- Assumes no breaking changes to existing budget edit/show workflows
- Database performance assumes typical budget has 10-30 categories
- Caching strategy assumes `entries_cache_version` invalidation works correctly

---

## Developer Handoff Checklist

Before considering sprint complete, ensure:

- [ ] All code merged to main branch
- [ ] Tests passing in CI
- [ ] Feature deployed to staging environment
- [ ] Manual QA completed on staging
- [ ] Documentation complete and committed
- [ ] Known issues documented in GitHub issues
- [ ] Changelog updated
- [ ] Product team notified and demo scheduled
