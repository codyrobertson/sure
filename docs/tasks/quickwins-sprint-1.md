# Quick Wins Sprint - Task Breakdown

## Overview

This document breaks down all 6 quick wins into atomic Units of Work (UOWs). Each UOW is designed to be completable in 1-2 hours by a single developer.

---

## Quick Win 1: PDF Export

**Total Estimated Effort**: 4 hours (S)
**Priority**: P2
**Dependencies**: None

### UOW-1.1: Add Prawn Gem Dependency

**Type**: infra
**Estimate**: 0.5 hours
**Dependencies**: None

**Exact Action**:
- Add `gem "prawn"` to Gemfile
- Run `bundle install`
- Verify gem installation with `bundle list | grep prawn`

**Files Modified**:
- `/Users/Cody/code_projects/sure/Gemfile`

**Acceptance Checks**:
- [ ] Prawn gem appears in Gemfile.lock
- [ ] Bundle install completes without errors
- [ ] Rails console can require 'prawn' successfully

---

### UOW-1.2: Uncomment PDF Export Code

**Type**: backend
**Estimate**: 0.5 hours
**Dependencies**: UOW-1.1

**Exact Action**:
- In `/Users/Cody/code_projects/sure/app/controllers/reports_controller.rb`:
  - Uncomment lines 92-97 (PDF format block in `export_transactions` action)
  - Verify `generate_transactions_pdf` method (lines 816-914) is intact
- Test PDF generation in Rails console

**Files Modified**:
- `/Users/Cody/code_projects/sure/app/controllers/reports_controller.rb`

**Acceptance Checks**:
- [ ] PDF format block is active
- [ ] No syntax errors
- [ ] Rails server starts without warnings

---

### UOW-1.3: Create PDF Export UI Component

**Type**: frontend
**Estimate**: 1 hour
**Dependencies**: UOW-1.2

**Exact Action**:
- Add "Download PDF" button to Reports page export section
- Add PDF icon using `icon` helper (not `lucide_icon`)
- Wire button to `export_transactions_reports_path(format: :pdf)`
- Use existing export dropdown pattern from CSV export

**Files Modified**:
- `/Users/Cody/code_projects/sure/app/views/reports/index.html.erb` or appropriate partial
- `/Users/Cody/code_projects/sure/config/locales/en.yml` (add i18n strings)

**Acceptance Checks**:
- [ ] Button appears in Reports export section
- [ ] Button styling matches existing design system
- [ ] Clicking button triggers PDF download
- [ ] All user-facing strings use i18n

---

### UOW-1.4: Test PDF Export with Various Data Sets

**Type**: tests
**Estimate**: 1.5 hours
**Dependencies**: UOW-1.3

**Exact Action**:
- Create controller test for PDF export in `/Users/Cody/code_projects/sure/test/controllers/reports_controller_test.rb`
- Test with: empty data, single month, multi-month, large dataset (100+ transactions)
- Verify PDF structure: headers, income section, expense section, totals
- Test error handling (missing data, invalid date ranges)

**Files Modified**:
- `/Users/Cody/code_projects/sure/test/controllers/reports_controller_test.rb`

**Acceptance Checks**:
- [ ] Test coverage for PDF export action
- [ ] Tests verify PDF content structure
- [ ] Tests pass with `bin/rails test`
- [ ] No regression in existing tests

---

### UOW-1.5: Add Analytics Tracking for PDF Downloads

**Type**: backend
**Estimate**: 0.5 hours
**Dependencies**: UOW-1.3

**Exact Action**:
- Add analytics event when PDF is generated
- Track: user_id, period_type, date_range, transaction_count
- Use existing analytics pattern (if available) or add TODO for analytics integration

**Files Modified**:
- `/Users/Cody/code_projects/sure/app/controllers/reports_controller.rb` (line ~93, in PDF format block)

**Acceptance Checks**:
- [ ] Analytics event fires on PDF download
- [ ] Event includes all required metadata
- [ ] No performance degradation

---

## Quick Win 2: Surface Anomaly Alerts

**Total Estimated Effort**: 16 hours (L)
**Priority**: P0
**Dependencies**: None

### UOW-2.1: Create Notification Model

**Type**: data
**Estimate**: 1.5 hours
**Dependencies**: None

**Exact Action**:
- Generate migration: `rails g model Notification family:references user:references notification_type:string severity:string data:jsonb read_at:datetime`
- Add validations: presence of family, notification_type, severity
- Add enum for severity: `enum severity: { info: "info", warning: "warning", alert: "alert" }`
- Add scopes: `scope :unread, -> { where(read_at: nil) }`

**Files Created**:
- `/Users/Cody/code_projects/sure/app/models/notification.rb`
- `/Users/Cody/code_projects/sure/db/migrate/XXXXXX_create_notifications.rb`

**Acceptance Checks**:
- [ ] Migration runs cleanly with `bin/rails db:migrate`
- [ ] Model validations work
- [ ] Factory/fixture exists for testing

---

### UOW-2.2: Create AnomalyNotificationJob

**Type**: backend
**Estimate**: 2 hours
**Dependencies**: UOW-2.1

**Exact Action**:
- Create background job: `app/jobs/anomaly_notification_job.rb`
- Job fetches anomalies using `Insights::AnomalyDetector.new(family, period: Period.current_month).analyze`
- For each anomaly with severity >= warning:
  - Check if notification already exists (deduplicate)
  - Create Notification record with type: "spending_anomaly"
  - Include anomaly data in jsonb column (category, current, average, deviation_percent)

**Files Created**:
- `/Users/Cody/code_projects/sure/app/jobs/anomaly_notification_job.rb`

**Acceptance Checks**:
- [ ] Job runs successfully
- [ ] Creates notifications for new anomalies
- [ ] Doesn't create duplicate notifications
- [ ] Handles edge cases (no anomalies, missing data)

---

### UOW-2.3: Schedule Daily Anomaly Detection

**Type**: infra
**Estimate**: 0.5 hours
**Dependencies**: UOW-2.2

**Exact Action**:
- Add sidekiq-cron schedule (or similar) to run AnomalyNotificationJob daily
- Schedule for early morning (e.g., 6 AM local time)
- Add job to appropriate config file (check existing scheduled jobs pattern)

**Files Modified**:
- Sidekiq schedule config (likely `/Users/Cody/code_projects/sure/config/initializers/sidekiq.rb` or similar)

**Acceptance Checks**:
- [ ] Job appears in scheduled jobs list
- [ ] Job runs at correct time
- [ ] Job processes all families

---

### UOW-2.4: Create Notification Component

**Type**: frontend
**Estimate**: 2 hours
**Dependencies**: UOW-2.1

**Exact Action**:
- Create ViewComponent: `app/components/notification_component.rb`
- Component displays notification with:
  - Icon (alert/warning based on severity)
  - Title and description
  - "Mark as read" action
  - Link to relevant page (Reports > Anomaly Detection)
- Support variants: inline (dashboard), toast, list item

**Files Created**:
- `/Users/Cody/code_projects/sure/app/components/notification_component.rb`
- `/Users/Cody/code_projects/sure/app/components/notification_component.html.erb`
- `/Users/Cody/code_projects/sure/app/components/notification_component_controller.js` (Stimulus)

**Acceptance Checks**:
- [ ] Component renders correctly
- [ ] Severity colors match design system
- [ ] "Mark as read" works
- [ ] Links to correct page

---

### UOW-2.5: Add Notifications to Dashboard

**Type**: frontend
**Estimate**: 2 hours
**Dependencies**: UOW-2.4

**Exact Action**:
- Add notifications widget to dashboard sections in `app/controllers/pages_controller.rb`
- Fetch unread notifications for current user/family
- Add dashboard partial: `app/views/pages/dashboard/_notifications.html.erb`
- Use NotificationComponent for each notification
- Add to collapsible sections array

**Files Modified**:
- `/Users/Cody/code_projects/sure/app/controllers/pages_controller.rb`
- `/Users/Cody/code_projects/sure/app/views/pages/dashboard/_notifications.html.erb` (new)
- `/Users/Cody/code_projects/sure/config/locales/en.yml`

**Acceptance Checks**:
- [ ] Widget appears on dashboard
- [ ] Shows unread notifications
- [ ] Widget is collapsible
- [ ] Empty state when no notifications

---

### UOW-2.6: Add Notification Preferences

**Type**: backend
**Estimate**: 1.5 hours
**Dependencies**: UOW-2.2

**Exact Action**:
- Add user preference fields (use existing preference pattern from User model)
- Add `anomaly_notifications_enabled` boolean (default: true)
- Add `anomaly_notification_threshold` enum (warning, alert)
- Update AnomalyNotificationJob to respect user preferences

**Files Modified**:
- `/Users/Cody/code_projects/sure/app/models/user.rb`
- `/Users/Cody/code_projects/sure/app/jobs/anomaly_notification_job.rb`
- Database migration for user preferences (if needed)

**Acceptance Checks**:
- [ ] User can toggle anomaly notifications
- [ ] User can set threshold
- [ ] Job respects preferences
- [ ] Preferences persist across sessions

---

### UOW-2.7: Add Notification Preferences UI

**Type**: frontend
**Estimate**: 2 hours
**Dependencies**: UOW-2.6

**Exact Action**:
- Add notification settings to Settings > Preferences page
- Add toggle for "Enable spending anomaly alerts"
- Add dropdown for "Alert threshold" (Warning at 150%, Alert at 200%, Custom)
- Use existing settings form pattern

**Files Modified**:
- `/Users/Cody/code_projects/sure/app/views/settings/preferences/edit.html.erb` (or similar)
- `/Users/Cody/code_projects/sure/app/controllers/settings/preferences_controller.rb` (or similar)
- `/Users/Cody/code_projects/sure/config/locales/en.yml`

**Acceptance Checks**:
- [ ] Settings page shows notification preferences
- [ ] Changes save correctly
- [ ] UI matches existing design patterns
- [ ] Help text explains thresholds

---

### UOW-2.8: Add NotificationsController

**Type**: backend
**Estimate**: 1.5 hours
**Dependencies**: UOW-2.1

**Exact Action**:
- Create `app/controllers/notifications_controller.rb`
- Add actions: `index`, `mark_as_read`, `mark_all_as_read`
- Add routes: `resources :notifications, only: [:index] do ... end`
- Return turbo_stream response for mark_as_read

**Files Created**:
- `/Users/Cody/code_projects/sure/app/controllers/notifications_controller.rb`

**Files Modified**:
- `/Users/Cody/code_projects/sure/config/routes.rb`

**Acceptance Checks**:
- [ ] Routes are accessible
- [ ] mark_as_read updates notification
- [ ] Turbo stream response works
- [ ] Scoped to current family

---

### UOW-2.9: Add Tests for Anomaly Notifications

**Type**: tests
**Estimate**: 2.5 hours
**Dependencies**: All UOW-2.x

**Exact Action**:
- Test Notification model validations
- Test AnomalyNotificationJob creates notifications
- Test NotificationComponent renders correctly
- Test NotificationsController actions
- Test user preferences integration

**Files Created/Modified**:
- `/Users/Cody/code_projects/sure/test/models/notification_test.rb`
- `/Users/Cody/code_projects/sure/test/jobs/anomaly_notification_job_test.rb`
- `/Users/Cody/code_projects/sure/test/components/notification_component_test.rb`
- `/Users/Cody/code_projects/sure/test/controllers/notifications_controller_test.rb`

**Acceptance Checks**:
- [ ] All tests pass
- [ ] Test coverage > 80%
- [ ] Edge cases covered

---

### UOW-2.10: Add Notification Badge to Header

**Type**: frontend
**Estimate**: 1 hour
**Dependencies**: UOW-2.8

**Exact Action**:
- Add notification bell icon to app header/navbar
- Show count badge for unread notifications
- Clicking opens notifications dropdown or navigates to notifications page
- Real-time update using Turbo Streams (optional enhancement)

**Files Modified**:
- `/Users/Cody/code_projects/sure/app/views/layouts/_header.html.erb` (or similar)
- `/Users/Cody/code_projects/sure/app/javascript/controllers/notifications_controller.js` (if needed)

**Acceptance Checks**:
- [ ] Bell icon appears in header
- [ ] Badge shows correct count
- [ ] Clicking navigates to notifications
- [ ] Count updates when notifications read

---

## Quick Win 3: Budget Alert Emails

**Total Estimated Effort**: 12 hours (M)
**Priority**: P0
**Dependencies**: None

### UOW-3.1: Create BudgetAlertMailer

**Type**: backend
**Estimate**: 1.5 hours
**Dependencies**: None

**Exact Action**:
- Create mailer: `app/mailers/budget_alert_mailer.rb` inheriting from ApplicationMailer
- Add method: `category_threshold_reached(budget_category, user)`
- Create email templates (HTML and text):
  - Subject: "Budget Alert: {{category_name}} at {{percent}}%"
  - Body: Show current spending, budget limit, days remaining, suggested daily spending
- Include link to budget page

**Files Created**:
- `/Users/Cody/code_projects/sure/app/mailers/budget_alert_mailer.rb`
- `/Users/Cody/code_projects/sure/app/views/budget_alert_mailer/category_threshold_reached.html.erb`
- `/Users/Cody/code_projects/sure/app/views/budget_alert_mailer/category_threshold_reached.text.erb`

**Acceptance Checks**:
- [ ] Mailer sends successfully
- [ ] Email renders correctly (HTML and text)
- [ ] Links work correctly
- [ ] Branded with app name and logo

---

### UOW-3.2: Create BudgetAlertJob

**Type**: backend
**Estimate**: 2.5 hours
**Dependencies**: UOW-3.1

**Exact Action**:
- Create job: `app/jobs/budget_alert_job.rb`
- Job logic:
  - Fetch all current month budgets
  - For each budget, check all budget_categories
  - If `percent_of_budget_spent >= alert_threshold` (default 80):
    - Check if alert already sent today (use cache or DB flag)
    - Send email via BudgetAlertMailer
    - Mark alert as sent
- Handle user preferences (alert threshold, email enabled)

**Files Created**:
- `/Users/Cody/code_projects/sure/app/jobs/budget_alert_job.rb`

**Acceptance Checks**:
- [ ] Job runs without errors
- [ ] Sends emails only for categories at/above threshold
- [ ] Doesn't send duplicate emails
- [ ] Respects user preferences

---

### UOW-3.3: Add Budget Alert Tracking

**Type**: data
**Estimate**: 1.5 hours
**Dependencies**: UOW-3.2

**Exact Action**:
- Create migration: `rails g migration AddBudgetAlertsSentToBudgetCategories`
- Add jsonb column: `alerts_sent` (stores {date => threshold} map)
- Add method to BudgetCategory: `alert_sent_today?(threshold)`
- Add method to BudgetCategory: `record_alert_sent(threshold)`

**Files Modified**:
- `/Users/Cody/code_projects/sure/app/models/budget_category.rb`
- `/Users/Cody/code_projects/sure/db/migrate/XXXXXX_add_budget_alerts_sent_to_budget_categories.rb`

**Acceptance Checks**:
- [ ] Migration runs cleanly
- [ ] Alert tracking works correctly
- [ ] Prevents duplicate alerts same day
- [ ] Clears old alert data (> 30 days)

---

### UOW-3.4: Schedule Daily Budget Alert Job

**Type**: infra
**Estimate**: 0.5 hours
**Dependencies**: UOW-3.2

**Exact Action**:
- Add sidekiq-cron schedule to run BudgetAlertJob daily
- Schedule for evening (e.g., 8 PM local time)
- Add to scheduled jobs config

**Files Modified**:
- Sidekiq schedule config

**Acceptance Checks**:
- [ ] Job appears in scheduled jobs
- [ ] Job runs at correct time
- [ ] Job processes all families

---

### UOW-3.5: Add Budget Alert Preferences to User Model

**Type**: backend
**Estimate**: 1 hour
**Dependencies**: None

**Exact Action**:
- Add user preference fields:
  - `budget_alerts_enabled` boolean (default: true)
  - `budget_alert_threshold` integer (default: 80, range: 50-100)
  - `budget_alert_email_enabled` boolean (default: true)
- Add validation: threshold between 50-100
- Update BudgetAlertJob to use user-specific thresholds

**Files Modified**:
- `/Users/Cody/code_projects/sure/app/models/user.rb`
- `/Users/Cody/code_projects/sure/app/jobs/budget_alert_job.rb`
- Database migration for user preferences

**Acceptance Checks**:
- [ ] Preferences save correctly
- [ ] Validation works
- [ ] Job uses user preferences
- [ ] Default values set correctly

---

### UOW-3.6: Add Budget Alert Preferences UI

**Type**: frontend
**Estimate**: 2 hours
**Dependencies**: UOW-3.5

**Exact Action**:
- Add to Settings > Preferences page:
  - Toggle: "Enable budget alerts"
  - Slider: "Alert threshold" (50-100%, default 80%)
  - Toggle: "Send email alerts"
- Use existing form pattern
- Show preview: "You'll be alerted when spending reaches $X (80% of $Y budget)"

**Files Modified**:
- Settings preferences view
- Settings preferences controller
- `/Users/Cody/code_projects/sure/config/locales/en.yml`

**Acceptance Checks**:
- [ ] UI shows all preference options
- [ ] Slider updates preview dynamically
- [ ] Changes save correctly
- [ ] Help text explains feature

---

### UOW-3.7: Add Budget Alert Preview to Budget Page

**Type**: frontend
**Estimate**: 1.5 hours
**Dependencies**: UOW-3.1

**Exact Action**:
- On budget show page, for each category near threshold:
  - Show warning badge: "Alert will be sent at {{threshold}}%"
  - Show progress indicator
  - Link to alert preferences
- Use existing budget category display pattern

**Files Modified**:
- `/Users/Cody/code_projects/sure/app/views/budgets/show.html.erb` or appropriate partial
- `/Users/Cody/code_projects/sure/config/locales/en.yml`

**Acceptance Checks**:
- [ ] Warning shows for categories approaching threshold
- [ ] Progress indicator accurate
- [ ] Link to preferences works
- [ ] Updates in real-time

---

### UOW-3.8: Add Tests for Budget Alerts

**Type**: tests
**Estimate**: 2 hours
**Dependencies**: All UOW-3.x

**Exact Action**:
- Test BudgetAlertMailer sends correctly
- Test BudgetAlertJob logic (threshold detection, deduplication)
- Test user preferences integration
- Test alert tracking (sent_today?, record_sent)
- Test mailer previews work

**Files Created/Modified**:
- `/Users/Cody/code_projects/sure/test/mailers/budget_alert_mailer_test.rb`
- `/Users/Cody/code_projects/sure/test/jobs/budget_alert_job_test.rb`
- `/Users/Cody/code_projects/sure/test/models/budget_category_test.rb` (update)

**Acceptance Checks**:
- [ ] All tests pass
- [ ] Edge cases covered
- [ ] Mailer preview works in dev

---

## Quick Win 4: Compare to Last Month Toggle

**Total Estimated Effort**: 8 hours (M)
**Priority**: P1
**Dependencies**: None

### UOW-4.1: Create Period Selector Component

**Type**: frontend
**Estimate**: 2 hours
**Dependencies**: None

**Exact Action**:
- Create ViewComponent: `app/components/period_selector_component.rb`
- Component renders dropdown with period options:
  - Current Month (MTD)
  - Last Month (LM)
  - Last 30 Days (30D)
  - Last 90 Days (90D)
  - Custom (opens date range picker)
- Use existing Period model options
- Component accepts current_period and callback URL

**Files Created**:
- `/Users/Cody/code_projects/sure/app/components/period_selector_component.rb`
- `/Users/Cody/code_projects/sure/app/components/period_selector_component.html.erb`
- `/Users/Cody/code_projects/sure/app/components/period_selector_component_controller.js`

**Acceptance Checks**:
- [ ] Component renders correctly
- [ ] Dropdown shows all period options
- [ ] Selecting period navigates with correct param
- [ ] Current period is highlighted

---

### UOW-4.2: Add Period Selector to Dashboard

**Type**: frontend
**Estimate**: 1 hour
**Dependencies**: UOW-4.1

**Exact Action**:
- Add PeriodSelectorComponent to dashboard header
- Position next to existing filter controls
- Wire to `pages_controller.rb` with `period` param
- Ensure all dashboard widgets use `@period`

**Files Modified**:
- `/Users/Cody/code_projects/sure/app/views/pages/dashboard.html.erb` (or header partial)
- `/Users/Cody/code_projects/sure/app/controllers/pages_controller.rb` (verify Periodable concern is included)

**Acceptance Checks**:
- [ ] Selector appears in dashboard header
- [ ] Changing period reloads dashboard with new data
- [ ] All widgets update correctly
- [ ] URL param persists

---

### UOW-4.3: Add Period Comparison Badge

**Type**: frontend
**Estimate**: 2 hours
**Dependencies**: UOW-4.2

**Exact Action**:
- Add comparison logic to `pages_controller.rb`:
  - Calculate previous period using existing `build_previous_period` pattern from reports_controller
  - Calculate % change for key metrics (income, expenses, net savings)
- Create ComparisonBadgeComponent:
  - Shows "↑ 15% vs last month" or "↓ 8% vs last month"
  - Color codes: green for positive income change, red for negative, inverse for expenses
- Add badge to dashboard summary metrics

**Files Created**:
- `/Users/Cody/code_projects/sure/app/components/comparison_badge_component.rb`
- `/Users/Cody/code_projects/sure/app/components/comparison_badge_component.html.erb`

**Files Modified**:
- `/Users/Cody/code_projects/sure/app/controllers/pages_controller.rb`
- Dashboard summary partial

**Acceptance Checks**:
- [ ] Badge shows correct % change
- [ ] Color coding works
- [ ] Handles edge cases (zero previous value)
- [ ] Responsive on mobile

---

### UOW-4.4: Add Default Period Preference

**Type**: backend
**Estimate**: 1 hour
**Dependencies**: None

**Exact Action**:
- Add user preference: `default_dashboard_period` string (default: "current_month")
- Update Periodable concern to use user's default when no param provided
- Validate against Period::PERIODS keys

**Files Modified**:
- `/Users/Cody/code_projects/sure/app/models/user.rb`
- `/Users/Cody/code_projects/sure/app/controllers/concerns/periodable.rb`
- Database migration for user preferences

**Acceptance Checks**:
- [ ] Preference saves correctly
- [ ] Dashboard uses user's default period
- [ ] URL param overrides default
- [ ] Invalid values fall back to current_month

---

### UOW-4.5: Add Default Period Preference UI

**Type**: frontend
**Estimate**: 1 hour
**Dependencies**: UOW-4.4

**Exact Action**:
- Add to Settings > Preferences page:
  - Dropdown: "Default dashboard period"
  - Options: Current Month, Last Month, Last 30 Days, Last 90 Days
- Use existing form pattern

**Files Modified**:
- Settings preferences view
- Settings preferences controller
- `/Users/Cody/code_projects/sure/config/locales/en.yml`

**Acceptance Checks**:
- [ ] Dropdown shows all options
- [ ] Selection saves correctly
- [ ] Dashboard uses selected default
- [ ] Change reflects immediately

---

### UOW-4.6: Add Tests for Period Comparison

**Type**: tests
**Estimate**: 1 hour
**Dependencies**: All UOW-4.x

**Exact Action**:
- Test PeriodSelectorComponent rendering
- Test ComparisonBadgeComponent logic (% calculation, color coding)
- Test user preference saves and loads
- Test Periodable concern uses default correctly

**Files Created/Modified**:
- `/Users/Cody/code_projects/sure/test/components/period_selector_component_test.rb`
- `/Users/Cody/code_projects/sure/test/components/comparison_badge_component_test.rb`
- `/Users/Cody/code_projects/sure/test/controllers/pages_controller_test.rb` (update)

**Acceptance Checks**:
- [ ] All tests pass
- [ ] Edge cases covered
- [ ] Component tests verify rendering

---

## Quick Win 5: Improve Rule Visibility

**Total Estimated Effort**: 12 hours (M)
**Priority**: P2
**Dependencies**: None

### UOW-5.1: Create Rules Dashboard Widget

**Type**: frontend
**Estimate**: 2 hours
**Dependencies**: None

**Exact Action**:
- Create widget partial: `app/views/pages/dashboard/_rules_widget.html.erb`
- Widget shows:
  - Active rules count
  - Recent rule runs (last 3)
  - "Create your first rule" CTA if no rules
  - Link to rules page
- Add to dashboard sections array in `pages_controller.rb`

**Files Created**:
- `/Users/Cody/code_projects/sure/app/views/pages/dashboard/_rules_widget.html.erb`

**Files Modified**:
- `/Users/Cody/code_projects/sure/app/controllers/pages_controller.rb`
- `/Users/Cody/code_projects/sure/config/locales/en.yml`

**Acceptance Checks**:
- [ ] Widget appears on dashboard
- [ ] Shows correct counts
- [ ] Links to rules page
- [ ] Empty state shows CTA

---

### UOW-5.2: Add Rules Count Badge to Transaction Header

**Type**: frontend
**Estimate**: 1.5 hours
**Dependencies**: None

**Exact Action**:
- In transactions index page header, add badge: "X rules active"
- Badge links to rules page
- Only show if rules exist
- Use existing badge styling pattern

**Files Modified**:
- `/Users/Cody/code_projects/sure/app/views/transactions/index.html.erb`
- `/Users/Cody/code_projects/sure/app/controllers/transactions_controller.rb` (add `@active_rules_count`)
- `/Users/Cody/code_projects/sure/config/locales/en.yml`

**Acceptance Checks**:
- [ ] Badge shows correct count
- [ ] Badge links to rules page
- [ ] Hidden when no rules
- [ ] Responsive styling

---

### UOW-5.3: Add "Create Rule" Quick Action to Transaction Detail

**Type**: frontend
**Estimate**: 2.5 hours
**Dependencies**: None

**Exact Action**:
- Add button to transaction detail dropdown: "Create rule from this transaction"
- Button pre-fills rule form with:
  - Condition: transaction name matches current transaction
  - Action: set category to current category
- Links to `new_rule_path` with query params
- Use existing rules_controller.rb `new` action (supports pre-filling via params)

**Files Modified**:
- `/Users/Cody/code_projects/sure/app/views/transactions/_transaction.html.erb` (or detail partial)
- `/Users/Cody/code_projects/sure/config/locales/en.yml`

**Acceptance Checks**:
- [ ] Button appears in transaction dropdown
- [ ] Clicking opens rule form
- [ ] Form pre-filled correctly
- [ ] Save creates working rule

---

### UOW-5.4: Add "Auto-categorized" Badge to Transactions

**Type**: backend
**Estimate**: 2 hours
**Dependencies**: None

**Exact Action**:
- Add method to Transaction model: `auto_categorized?`
  - Check if transaction has `locked_attributes` including category_id
  - OR check if category was set by a rule (requires tracking)
- If tracking needed:
  - Add `categorized_by_rule_id` to transactions (migration)
  - Update rule actions to set this field
- Add badge to transaction list item: "Auto-categorized"

**Files Modified**:
- `/Users/Cody/code_projects/sure/app/models/transaction.rb`
- `/Users/Cody/code_projects/sure/app/models/rule.rb` (or action executor)
- `/Users/Cody/code_projects/sure/app/views/transactions/_transaction.html.erb`
- `/Users/Cody/code_projects/sure/config/locales/en.yml`
- Database migration (if adding column)

**Acceptance Checks**:
- [ ] Badge shows for auto-categorized transactions
- [ ] Badge hidden for manual categorization
- [ ] Tooltip explains which rule applied
- [ ] Badge styling matches design system

---

### UOW-5.5: Add Rule Suggestion Banner

**Type**: frontend
**Estimate**: 2 hours
**Dependencies**: None

**Exact Action**:
- On transactions page, if user has 0 rules and 20+ transactions:
  - Show dismissible banner: "Save time! Create rules to auto-categorize similar transactions"
  - Banner includes "Learn more" link and "Create rule" button
- Banner dismisses for 7 days when closed
- Use browser localStorage or user preference

**Files Created**:
- `/Users/Cody/code_projects/sure/app/components/rule_suggestion_banner_component.rb`
- `/Users/Cody/code_projects/sure/app/components/rule_suggestion_banner_component.html.erb`

**Files Modified**:
- `/Users/Cody/code_projects/sure/app/views/transactions/index.html.erb`
- `/Users/Cody/code_projects/sure/config/locales/en.yml`

**Acceptance Checks**:
- [ ] Banner shows when conditions met
- [ ] Banner dismisses correctly
- [ ] Dismiss state persists
- [ ] Links work correctly

---

### UOW-5.6: Add Tests for Rule Visibility Features

**Type**: tests
**Estimate**: 2 hours
**Dependencies**: All UOW-5.x

**Exact Action**:
- Test rules dashboard widget renders
- Test rules count badge
- Test "Create rule" quick action pre-fills form
- Test auto-categorized badge logic
- Test rule suggestion banner conditions

**Files Created/Modified**:
- `/Users/Cody/code_projects/sure/test/components/rule_suggestion_banner_component_test.rb`
- `/Users/Cody/code_projects/sure/test/models/transaction_test.rb` (update)
- `/Users/Cody/code_projects/sure/test/controllers/transactions_controller_test.rb` (update)
- `/Users/Cody/code_projects/sure/test/system/rules_test.rb` (system test for create flow)

**Acceptance Checks**:
- [ ] All tests pass
- [ ] System test verifies end-to-end flow
- [ ] Edge cases covered

---

## Quick Win 6: Transaction/Merchant Merge UI

**Total Estimated Effort**: 20 hours (L)
**Priority**: P1
**Dependencies**: None

### UOW-6.1: Add Multi-Select to Transaction List

**Type**: frontend
**Estimate**: 2.5 hours
**Dependencies**: None

**Exact Action**:
- Add checkbox column to transaction table
- Add "Select all" checkbox in header
- Add Stimulus controller for multi-select behavior
- Show/hide bulk actions toolbar when selections change
- Store selected transaction IDs in controller state

**Files Modified**:
- `/Users/Cody/code_projects/sure/app/views/transactions/index.html.erb`
- `/Users/Cody/code_projects/sure/app/views/transactions/_transaction.html.erb`
- `/Users/Cody/code_projects/sure/app/javascript/controllers/transaction_multi_select_controller.js` (new)
- `/Users/Cody/code_projects/sure/config/locales/en.yml`

**Acceptance Checks**:
- [ ] Checkboxes appear in transaction list
- [ ] Select all works
- [ ] Selection state tracked correctly
- [ ] Bulk actions toolbar shows/hides

---

### UOW-6.2: Create Bulk Actions Toolbar Component

**Type**: frontend
**Estimate**: 1.5 hours
**Dependencies**: UOW-6.1

**Exact Action**:
- Create component: `app/components/bulk_actions_toolbar_component.rb`
- Toolbar shows:
  - Selected count: "X transactions selected"
  - Actions dropdown: Merge, Delete, Clear selection
  - Sticky positioning at top of table
- Use existing design system patterns

**Files Created**:
- `/Users/Cody/code_projects/sure/app/components/bulk_actions_toolbar_component.rb`
- `/Users/Cody/code_projects/sure/app/components/bulk_actions_toolbar_component.html.erb`

**Acceptance Checks**:
- [ ] Toolbar renders when items selected
- [ ] Count updates dynamically
- [ ] Dropdown shows all actions
- [ ] Sticky positioning works

---

### UOW-6.3: Create TransactionMergeService

**Type**: backend
**Estimate**: 3 hours
**Dependencies**: None

**Exact Action**:
- Create service: `app/services/transaction_merge_service.rb`
- Service accepts: primary_transaction_id, transaction_ids_to_merge
- Service logic:
  - Validate all transactions belong to same family
  - Extract attributes from primary transaction (category, merchant, tags)
  - Update all merge transactions with primary attributes
  - Store previous values in jsonb column for undo (24 hour retention)
  - Return summary: {updated_count, errors}
- Handle attribute locks (skip locked attributes)

**Files Created**:
- `/Users/Cody/code_projects/sure/app/services/transaction_merge_service.rb`

**Acceptance Checks**:
- [ ] Service merges transactions correctly
- [ ] Respects attribute locks
- [ ] Stores undo data
- [ ] Returns useful summary
- [ ] Handles errors gracefully

---

### UOW-6.4: Add Merge Undo Tracking

**Type**: data
**Estimate**: 1.5 hours
**Dependencies**: UOW-6.3

**Exact Action**:
- Create migration: `rails g migration AddMergeUndoDataToTransactions`
- Add jsonb column: `merge_undo_data` (stores previous values)
- Add datetime column: `merge_undo_expires_at`
- Add method to Transaction: `can_undo_merge?`
- Add cleanup job to remove expired undo data

**Files Modified**:
- `/Users/Cody/code_projects/sure/app/models/transaction.rb`
- `/Users/Cody/code_projects/sure/db/migrate/XXXXXX_add_merge_undo_data_to_transactions.rb`
- `/Users/Cody/code_projects/sure/app/jobs/cleanup_merge_undo_data_job.rb` (new)

**Acceptance Checks**:
- [ ] Migration runs cleanly
- [ ] Undo data stored correctly
- [ ] Expiration tracked
- [ ] Cleanup job works

---

### UOW-6.5: Add Bulk Merge Action to TransactionsController

**Type**: backend
**Estimate**: 2 hours
**Dependencies**: UOW-6.3, UOW-6.4

**Exact Action**:
- Add action to `transactions_controller.rb`: `bulk_merge`
- Action receives: primary_id, transaction_ids[]
- Call TransactionMergeService
- Return turbo_stream response to update transaction list
- Flash success/error message
- Add route: `post :bulk_merge, on: :collection`

**Files Modified**:
- `/Users/Cody/code_projects/sure/app/controllers/transactions_controller.rb`
- `/Users/Cody/code_projects/sure/config/routes.rb`

**Acceptance Checks**:
- [ ] Action accessible via POST
- [ ] Calls merge service
- [ ] Returns turbo_stream
- [ ] Shows flash message
- [ ] Scoped to family

---

### UOW-6.6: Create Merge Confirmation Modal

**Type**: frontend
**Estimate**: 2.5 hours
**Dependencies**: UOW-6.5

**Exact Action**:
- Create modal component: `app/components/transaction_merge_modal_component.rb`
- Modal shows:
  - Selected transactions count
  - "Choose primary transaction" radio buttons
  - Preview of changes (category, merchant, tags)
  - Confirm/Cancel buttons
- Use native `<dialog>` element
- Submit triggers bulk_merge action

**Files Created**:
- `/Users/Cody/code_projects/sure/app/components/transaction_merge_modal_component.rb`
- `/Users/Cody/code_projects/sure/app/components/transaction_merge_modal_component.html.erb`
- `/Users/Cody/code_projects/sure/app/components/transaction_merge_modal_component_controller.js`

**Acceptance Checks**:
- [ ] Modal opens on "Merge" action
- [ ] Shows all selected transactions
- [ ] Primary selection works
- [ ] Preview updates dynamically
- [ ] Confirm triggers merge

---

### UOW-6.7: Create MerchantMergeService

**Type**: backend
**Estimate**: 2.5 hours
**Dependencies**: None

**Exact Action**:
- Create service: `app/services/merchant_merge_service.rb`
- Service accepts: primary_merchant_id, merchant_ids_to_merge
- Service logic:
  - Validate all merchants belong to same family (if family-scoped)
  - Update all transactions with duplicate merchants to use primary merchant
  - Delete duplicate merchant records
  - Return summary: {transactions_updated, merchants_deleted}

**Files Created**:
- `/Users/Cody/code_projects/sure/app/services/merchant_merge_service.rb`

**Acceptance Checks**:
- [ ] Service merges merchants correctly
- [ ] Updates all related transactions
- [ ] Deletes duplicate merchants
- [ ] Returns useful summary
- [ ] Handles errors

---

### UOW-6.8: Add Merchant Merge UI to Merchants Page

**Type**: frontend
**Estimate**: 2 hours
**Dependencies**: UOW-6.7

**Exact Action**:
- If merchants index page exists, add multi-select similar to transactions
- If no merchants page exists, add "Manage merchants" link to settings
- Add bulk merge action for merchants
- Create merchant_merge_modal similar to transaction merge
- Wire to MerchantMergeService

**Files Modified**:
- Merchant-related views (if exist)
- `/Users/Cody/code_projects/sure/app/controllers/merchants_controller.rb` (create if needed)
- `/Users/Cody/code_projects/sure/config/routes.rb`

**Acceptance Checks**:
- [ ] Merchant list shows multi-select
- [ ] Merge action works
- [ ] Modal confirms merge
- [ ] Transactions updated correctly

---

### UOW-6.9: Add Undo Merge Feature

**Type**: backend + frontend
**Estimate**: 2 hours
**Dependencies**: UOW-6.4

**Exact Action**:
- Add action to transactions_controller: `undo_merge`
- Action restores transaction attributes from merge_undo_data
- Add "Undo merge" button to flash message (visible for 24 hours)
- Button only shows if merge_undo_data exists and not expired
- Clear undo data after restoration

**Files Modified**:
- `/Users/Cody/code_projects/sure/app/controllers/transactions_controller.rb`
- `/Users/Cody/code_projects/sure/app/models/transaction.rb`
- Flash notification partial (to include undo button)
- `/Users/Cody/code_projects/sure/config/routes.rb`

**Acceptance Checks**:
- [ ] Undo button appears in flash
- [ ] Clicking undo restores values
- [ ] Undo expires after 24 hours
- [ ] Undo data cleared after use

---

### UOW-6.10: Add Tests for Merge Features

**Type**: tests
**Estimate**: 3 hours
**Dependencies**: All UOW-6.x

**Exact Action**:
- Test TransactionMergeService logic
- Test MerchantMergeService logic
- Test bulk_merge controller action
- Test undo_merge controller action
- Test multi-select component behavior
- Test merge modal component
- System test for end-to-end merge flow

**Files Created/Modified**:
- `/Users/Cody/code_projects/sure/test/services/transaction_merge_service_test.rb`
- `/Users/Cody/code_projects/sure/test/services/merchant_merge_service_test.rb`
- `/Users/Cody/code_projects/sure/test/controllers/transactions_controller_test.rb` (update)
- `/Users/Cody/code_projects/sure/test/components/transaction_merge_modal_component_test.rb`
- `/Users/Cody/code_projects/sure/test/system/transaction_merge_test.rb` (new)

**Acceptance Checks**:
- [ ] All tests pass
- [ ] Edge cases covered
- [ ] System test verifies full flow
- [ ] Undo logic tested

---

## Summary

### Total Units of Work: 50 UOWs

### Estimated Hours by Quick Win:
1. **PDF Export**: 4 hours (5 UOWs)
2. **Surface Anomaly Alerts**: 16 hours (10 UOWs)
3. **Budget Alert Emails**: 12 hours (8 UOWs)
4. **Compare to Last Month**: 8 hours (6 UOWs)
5. **Improve Rule Visibility**: 12 hours (6 UOWs)
6. **Transaction/Merchant Merge**: 20 hours (10 UOWs)

**Total**: 72 hours (~9 days with buffer)

### Complexity Distribution:
- **Small (S)**: 1 quick win (PDF Export)
- **Medium (M)**: 3 quick wins (Budget Alerts, Period Toggle, Rule Visibility)
- **Large (L)**: 2 quick wins (Anomaly Alerts, Merge UI)

### Files Frequently Modified:
- `/Users/Cody/code_projects/sure/config/locales/en.yml` (all i18n strings)
- `/Users/Cody/code_projects/sure/app/controllers/pages_controller.rb` (dashboard)
- `/Users/Cody/code_projects/sure/app/controllers/transactions_controller.rb` (transactions)
- `/Users/Cody/code_projects/sure/app/models/user.rb` (preferences)

### Critical Dependencies:
- All UOWs are independently testable
- No blocking dependencies between quick wins
- Can be deployed incrementally
- Feature flags recommended for gradual rollout

### Pre-Development Checklist:
- [ ] All fixtures updated for new models
- [ ] i18n keys planned (create placeholder file)
- [ ] Design system tokens reviewed
- [ ] Analytics events defined
- [ ] Feature flags configured
- [ ] Rollback plan documented
