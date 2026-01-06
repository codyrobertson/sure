# Epic: Budget Intelligence Dashboard

## Overview

Transform the existing budget feature from a static allocation tool into an intelligent, real-time tracking system that provides actionable insights, proactive alerts, and AI-powered variance explanations. This epic extends the current Budget and BudgetCategory models with visualization, tracking, and intelligence capabilities.

## Business Value

### User Problems Solved
1. **Lack of Real-Time Awareness**: Users currently allocate budgets but lack continuous visibility into spending progress throughout the month
2. **Reactive vs Proactive**: Users discover budget overruns after they happen rather than being warned when approaching limits
3. **Missing Context**: Users see variances but don't understand why they occurred or what actions to take
4. **No Pace Tracking**: Users can't easily tell if they're "on track" to meet their budget given the days remaining in the period

### Business Impact
- **Increased Engagement**: Real-time dashboards drive daily/weekly usage vs monthly check-ins
- **Reduced Financial Stress**: Proactive alerts prevent surprise overdrafts and budget failures
- **Competitive Differentiation**: AI-powered budget insights distinguish from basic tracking tools (Mint, YNAB alternatives)
- **Data Quality**: Active budget monitoring encourages better transaction categorization

### Success Metrics
- 60%+ of active users view budget dashboard at least weekly
- 40%+ reduction in budget overruns month-over-month after feature launch
- 80%+ of users with active budgets receive and act on at least one alert per month
- Improved transaction categorization rate (fewer "Uncategorized" transactions)

## Current State Analysis

### Existing Budget Infrastructure
The codebase already has a solid foundation:

**Models:**
- `Budget`: Month-based budgets with income/expense tracking
  - Already calculates: `actual_spending`, `available_to_spend`, `percent_of_budget_spent`
  - Already supports: period-based queries, budget vs actual comparisons
  - Already monetizes: all financial fields through `Monetizable` concern

- `BudgetCategory`: Category-level budget allocations
  - Already calculates: `available_to_spend`, `percent_of_budget_spent`, `suggested_daily_spending`
  - Already has: `over_budget?`, `near_limit?` helper methods
  - Already supports: hierarchical categories (parent/subcategories)

**Controllers:**
- `BudgetsController`: Basic CRUD operations
- `BudgetCategoriesController`: Category allocation management

**Views:**
- Budget donut charts (overall and category-level)
- Budget summary panels (budgeted vs actual)
- Category breakdowns with progress indicators

**Data Layer:**
- `IncomeStatement`: Aggregates transaction data by category and period
- `Transaction`: Already has category associations, date ranges, visibility filtering
- Strong caching infrastructure via `entries_cache_version`

### What's Missing (Gaps to Fill)
1. **No dedicated dashboard view**: Budget data is scattered across show/edit pages
2. **No proactive alerting**: Users must manually check budget status
3. **No "on pace" indicators**: No projection of where spending will land by month-end
4. **No AI variance explanations**: Users see numbers but not context
5. **No trend/pattern analysis**: No comparison to historical spending patterns
6. **Limited time-based insights**: No daily/weekly pacing views
7. **No actionable recommendations**: No suggestions on how to adjust behavior

## Technical Approach

### Extend Existing vs Build New

**Extend These Existing Components:**
- `Budget` model: Add projection/forecasting methods
- `BudgetCategory` model: Add pacing/trend analysis methods
- `BudgetsController`: Add `dashboard` action alongside `show`
- Reuse existing: Donut chart components, monetization, period queries

**Build New Components:**
- `BudgetInsights` service/model: AI-powered variance analysis
- `BudgetAlert` model: Store and track alert history
- `BudgetProjection` calculator: Forecast end-of-month spending
- `BudgetDashboard` view component: Consolidated progress view
- `BudgetTrend` analyzer: Compare current vs historical patterns
- `Assistant::Function::GetBudgetInsights`: AI assistant integration

### Architecture Decisions

**Philosophy Alignment:**
- Follow "Skinny Controllers, Fat Models" - business logic in `app/models/budget_insights.rb`
- Avoid new dependencies - use existing charting (D3.js), no new npm packages
- Leverage existing infrastructure - reuse `IncomeStatement`, caching, `Period` helpers
- Hotwire-first - Turbo frames for real-time updates, no heavy JS

**Data Storage Strategy:**
- **No new tables for MVP** - calculate insights on-demand from existing data
- Use Rails caching for expensive calculations (following `IncomeStatement` pattern)
- Store alert preferences in User model (JSON column or separate preferences table later)
- Future phase: `BudgetAlert` table for alert history/audit trail

**Performance Considerations:**
- Leverage existing `entries_cache_version` for intelligent cache invalidation
- Pre-calculate common aggregations in background jobs if needed
- Use database indexes on `entries.date`, `transactions.category_id` (already exist)
- Paginate/limit AI insights to current + previous month

**UI/UX Strategy:**
- Add new "Dashboard" tab to existing budget nav (alongside "Edit")
- Reuse existing design system components (`DS::Alert`, `DS::Tabs`, donut charts)
- Mobile-first responsive design (following existing patterns)
- Collapsible sections for progressive disclosure

## User Stories & Acceptance Criteria

### Story 1: Budget Progress Dashboard
**As a** budget-conscious user
**I want to** see a real-time dashboard of my budget progress
**So that** I can stay aware of my spending without manually calculating variances

**Acceptance Criteria:**
- Given I have an active budget for the current month
- When I navigate to the budget dashboard
- Then I see:
  - Overall budget progress (% spent, amount remaining, days left in month)
  - Category-by-category breakdown with visual progress bars
  - Color-coded status indicators (on track / warning / over budget)
  - "On pace to spend $X by month end" projection
  - Comparison to typical spending for this category
- All monetary values use family currency formatting
- Dashboard loads in under 2 seconds
- Data refreshes automatically when transactions sync

### Story 2: Category-Level Tracking with Pace Indicators
**As a** user monitoring specific spending categories
**I want to** see if I'm spending too fast or too slow for each category
**So that** I can adjust my behavior before hitting limits

**Acceptance Criteria:**
- Given I have budget allocations for multiple categories
- When I view the budget dashboard
- Then for each category I see:
  - Visual progress bar showing % of budget used
  - "Pace" indicator: "On track" / "Ahead of pace" / "Behind pace"
  - Recommended daily spending for remainder of month
  - Comparison to average spending rate for this category
  - Quick link to view transactions in that category
- Categories are sorted by "at risk" status (over budget first, then near limit)
- Subcategories roll up into parent categories correctly
- Zero-budget categories show as "tracking only" mode

### Story 3: Proactive Budget Alerts
**As a** user who wants to avoid budget overruns
**I want to** receive alerts when approaching or exceeding budget limits
**So that** I can take corrective action before it's too late

**Acceptance Criteria:**
- Given I have active budgets with allocated categories
- When spending reaches defined thresholds:
  - 75% of budget: "Approaching limit" warning
  - 90% of budget: "Near limit" alert (if enabled)
  - 100% of budget: "Budget exceeded" alert
  - Projected to exceed by month-end: "Pace warning"
- Then I see alerts in:
  - Budget dashboard (prominent alert banner at top)
  - Optional: In-app notifications (future phase)
  - Optional: Email digest (future phase)
- Alerts are category-specific and include:
  - Category name and icon
  - Current spending vs budget
  - Amount remaining (or overage amount)
  - Suggested action (e.g., "Reduce dining spending to $X/day")
- Alerts can be dismissed but reappear if condition persists
- Alert thresholds are configurable per user

### Story 4: AI-Powered Variance Explanations
**As a** user trying to understand budget variances
**I want to** receive AI-generated explanations of why I'm over/under budget
**So that** I can understand spending patterns and make informed adjustments

**Acceptance Criteria:**
- Given I'm viewing a budget category with significant variance (>20% from budget)
- When I click "Explain variance" or view category details
- Then the AI assistant analyzes:
  - Large/unusual transactions in that category this period
  - Comparison to historical spending in this category
  - Day-of-week or timing patterns (e.g., "3 large weekend expenses")
  - Merchant-level insights (e.g., "Increased Amazon purchases")
- And provides a natural language summary like:
  - "You spent $200 more than usual on Groceries this month, primarily due to 2 large Costco trips totaling $350."
  - "Dining spending is 40% higher than your 3-month average, driven by 5 weekend dinners averaging $80 each."
- Explanation includes:
  - Root cause identification
  - Specific transaction examples (linked)
  - Historical context
  - Actionable recommendation
- Explanations are generated on-demand (not pre-calculated)
- Uses existing Assistant infrastructure (`Assistant::Function` pattern)

### Story 5: Budget Recommendations
**As a** user who struggles to set realistic budgets
**I want to** receive data-driven budget recommendations
**So that** I can create achievable budgets based on actual spending patterns

**Acceptance Criteria:**
- Given I'm creating or editing a budget
- When I view a category without an allocation
- Then I see AI-powered recommendations:
  - "Suggested budget: $X based on 3-month average"
  - "Median monthly spending: $Y"
  - "Range: $min - $max over past 6 months"
- Recommendations account for:
  - Historical spending patterns (median, not just average)
  - Seasonal variations (if sufficient data)
  - Recent trends (weighted toward recent months)
- User can "Accept suggestion" to auto-fill the budget amount
- User can adjust the lookback period (3 months / 6 months / 1 year)
- Recommendations clearly indicate data source (e.g., "Based on 6 months of data")

## Dependencies & Prerequisites

### Technical Dependencies
- **Existing Models**: `Budget`, `BudgetCategory`, `Transaction`, `Category`, `IncomeStatement`
- **Existing Infrastructure**: Hotwire (Turbo/Stimulus), D3.js charting, `Period` helpers
- **Caching Layer**: Rails cache with `entries_cache_version` invalidation
- **AI Integration**: Existing `Assistant` and `Assistant::Function` framework

### Data Prerequisites
- User must have at least one active budget
- Budget must have allocated categories to show meaningful insights
- Sufficient transaction history (ideally 3+ months) for trend analysis
- Transactions must be categorized (uncategorized transactions skew insights)

### External Dependencies
- None (purely extends existing functionality)

## Out of Scope (Future Phases)

The following are explicitly excluded from MVP (Sprint 1):

### Phase 2 Features:
- Email/push notification delivery for alerts
- Recurring budget templates (auto-create next month's budget)
- Budget sharing/collaboration between family members
- Historical budget performance reports (6-month trend view)
- Budget vs budget comparisons (month-over-month)

### Phase 3 Features:
- Goal-based budgeting (save for vacation, pay off debt)
- Multi-month budget planning (quarterly/annual budgets)
- "What-if" budget scenarios (what if I reduce dining by 20%?)
- Budget rollover (unused budget carries to next month)
- Integration with external budget tools (YNAB import)

### Technical Debt / Nice-to-Haves:
- Real-time websocket updates for live budget changes
- Mobile app push notifications
- Exportable budget reports (PDF/Excel)
- Custom alert threshold configuration UI
- Budget comparison to peer averages (anonymized)

## Risks & Mitigation Strategies

### Risk 1: Performance Degradation
**Risk**: Dashboard queries become slow with large transaction volumes
**Impact**: High - Poor UX, user abandonment
**Mitigation**:
- Leverage existing caching infrastructure (`entries_cache_version`)
- Pre-calculate expensive aggregations in background jobs
- Add database indexes if query analysis reveals bottlenecks
- Limit AI insights to current + previous month only
- Use pagination for large category lists

### Risk 2: AI Explanation Quality
**Risk**: AI-generated variance explanations are generic or unhelpful
**Impact**: Medium - Users ignore feature, reduced value proposition
**Mitigation**:
- Provide rich, structured data to AI function (not just summary stats)
- Include specific transaction examples in prompt context
- Use prompt engineering to enforce actionable recommendations
- Fallback to rule-based explanations for edge cases
- Gather user feedback and iterate on prompts

### Risk 3: Alert Fatigue
**Risk**: Too many alerts cause users to ignore all notifications
**Impact**: Medium - Defeats purpose of proactive alerting
**Mitigation**:
- Default to conservative thresholds (90% and 100% only)
- Limit to 1 alert per category per day
- Allow per-category alert configuration
- Make alerts dismissible with "don't show again" option
- Provide alert summary digest (not individual notifications)

### Risk 4: Insufficient Historical Data
**Risk**: New users or sparse transaction history yields poor insights
**Impact**: Low - Graceful degradation acceptable
**Mitigation**:
- Require minimum 2 months of data for trend analysis
- Show "Insufficient data" message with guidance to continue budgeting
- Use median instead of average to reduce outlier impact
- Fall back to simpler insights when data is limited
- Encourage CSV import to backfill history

### Risk 5: Budget Model Assumptions
**Risk**: Current monthly budget model doesn't fit all user needs
**Impact**: Medium - Some users may need weekly or custom periods
**Mitigation**:
- MVP focuses on monthly budgets (existing model)
- Document user requests for custom periods as Phase 2 feature
- Ensure architecture supports future period flexibility
- Use existing `Period` helpers to abstract date logic

## Success Criteria & Testing Strategy

### Definition of Done (MVP)
- [ ] Budget dashboard view accessible from budget nav
- [ ] Real-time progress tracking for overall budget and all categories
- [ ] "On pace" projections displayed for current month
- [ ] At least 3 alert types functional (approaching, exceeded, pace warning)
- [ ] AI variance explanation available via "Explain" link or assistant
- [ ] Budget recommendations based on historical data
- [ ] All existing budget functionality remains intact
- [ ] Mobile responsive design
- [ ] Comprehensive test coverage (Minitest)
- [ ] i18n keys for all user-facing strings

### Testing Approach

**Unit Tests** (`test/models/`)
- `BudgetInsights`: Variance calculation logic, edge cases
- `BudgetProjection`: End-of-month forecasting accuracy
- `Budget`: New projection methods, edge cases (negative budgets, zero spending)
- `BudgetCategory`: Pace indicators, alert thresholds

**Integration Tests** (`test/controllers/`)
- `BudgetsController#dashboard`: Proper data loading, permissions
- Alert generation triggered by spending thresholds
- AI function calls return valid response structure

**System Tests** (`test/system/`) - Use sparingly
- Critical user flow: View dashboard, see alerts, drill into category
- Mobile responsive layout
- Alert dismissal and re-appearance behavior

**Manual QA Checklist**
- [ ] Dashboard loads with real transaction data
- [ ] Alerts appear at correct thresholds (75%, 90%, 100%)
- [ ] AI explanations are relevant and actionable
- [ ] Budget recommendations use historical median
- [ ] All monetary values formatted correctly
- [ ] No N+1 queries (use bullet gem or query log analysis)
- [ ] Caching works (second load is instant)
- [ ] i18n strings display correctly

## Documentation Requirements

### User-Facing Documentation
- [ ] Feature announcement blog post (marketing copy)
- [ ] In-app onboarding tooltip or tour for new dashboard
- [ ] Help article: "Understanding Budget Alerts"
- [ ] Help article: "How Budget Projections Work"
- [ ] FAQ: "Why is my variance different from expected?"

### Developer Documentation
- [ ] ARCHITECTURE.md: Budget intelligence data flow diagram
- [ ] Code comments in `BudgetInsights` explaining calculation methodology
- [ ] README update: New budget dashboard feature
- [ ] API documentation (if exposing insights via API)

### Handoff Documentation
- [ ] This epic document (comprehensive planning)
- [ ] Sprint task breakdown (separate document)
- [ ] Test plan with expected behaviors
- [ ] Rollout plan (feature flag strategy if applicable)

## Rollout Strategy

### MVP Launch (Sprint 1 Complete)
- **Target**: 100% of users with active budgets
- **Feature Flag**: None (low risk, extends existing feature)
- **Monitoring**: Track dashboard page views, alert generation count, AI function calls
- **Success Metrics**: 50%+ adoption within 2 weeks

### Phase 2 (Future)
- Email/push notifications (opt-in)
- Historical budget performance reports
- Budget templates and automation

### Phase 3 (Future)
- Goal-based budgeting
- Multi-period planning
- Advanced scenarios

## Open Questions & Decisions Needed

### Questions for Product/Design
1. **Alert Delivery**: In-app only for MVP, or include email digest?
   - **Decision**: In-app only for MVP (faster, less infrastructure)

2. **Dashboard Placement**: New top-level nav item or sub-page of budgets?
   - **Decision**: Default view when navigating to `/budgets/:month_year`

3. **AI Tone**: Casual/friendly or professional/formal for explanations?
   - **Decision**: Follow existing assistant tone (helpful, conversational)

4. **Alert Thresholds**: Fixed (75%, 90%, 100%) or user-configurable?
   - **Decision**: Fixed for MVP, configurable in Phase 2

### Technical Decisions
1. **Caching Strategy**: Cache full dashboard state or individual components?
   - **Decision**: Cache individual calculations (follows existing pattern)

2. **Real-Time Updates**: Polling, websockets, or manual refresh?
   - **Decision**: Turbo frame auto-refresh on transaction sync (existing mechanism)

3. **AI Function Scope**: Separate function or extend `get_income_statement`?
   - **Decision**: New `get_budget_insights` function for focused interface

4. **Mobile Experience**: Separate mobile view or responsive single view?
   - **Decision**: Single responsive view (follows existing pattern)

## Related Epics & Features

### Prerequisite Features (Already Complete)
- Budget creation and allocation (existing)
- Transaction categorization (existing)
- Income statement reporting (existing)
- AI assistant framework (existing)

### Complementary Features (Can Build in Parallel)
- Improved transaction search/filtering
- Merchant intelligence
- Recurring transaction detection
- Cash flow forecasting

### Future Epic Dependencies (Blocked Until This Completes)
- Goal-based savings planning (needs budget insights)
- Spending recommendations (needs variance analysis)
- Family budget collaboration (needs dashboard foundation)

---

## Summary

This epic transforms the Sure budget feature from a planning tool into an intelligent tracking and alerting system. By leveraging existing infrastructure (Budget models, IncomeStatement, Assistant framework) and following established architectural patterns (fat models, Hotwire-first, minimal dependencies), we can deliver high-value insights with minimal technical risk.

**Key Differentiators**:
- Real-time awareness vs static monthly review
- Proactive alerts vs reactive discovery
- AI-powered context vs raw numbers
- Actionable recommendations vs guesswork

**Implementation Philosophy**:
- Extend, don't replace existing functionality
- Reuse proven patterns and infrastructure
- Focus on user value, not technical complexity
- Ship iteratively, gather feedback, improve
