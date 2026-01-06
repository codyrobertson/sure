# Quick Wins Sprint - Q1 2026

## Overview

This epic covers 6 high-impact, low-effort improvements to the Sure finance app. These features leverage existing infrastructure and analytics capabilities to deliver immediate value to users with minimal development time.

**Sprint Duration**: 1-2 weeks
**Total Estimated Effort**: 5-7 days
**Risk Level**: Low

## Business Value Summary

Each quick win is designed to:
- Surface existing hidden value (anomaly detection, rules)
- Reduce manual work (merge duplicates, PDF exports)
- Improve decision-making (budget alerts, period comparison)
- Increase feature discoverability (rule visibility)

## Quick Win Inventory

### 1. Surface Anomaly Alerts (Priority: P0)

**Business Value**: High
**Effort**: Small
**User Impact**: Proactive spending alerts catch budget overruns before they happen

**Current State**:
- `Insights::AnomalyDetector` fully functional and producing rich data
- Detects spending deviations (150%+ warning, 200%+ alert)
- Detects new merchants
- Currently only visible in Reports page, buried in insights section

**What We're Building**:
- In-app notification system for anomalies (severity: warning, alert)
- Dashboard widget showing active anomalies
- User preference to enable/disable anomaly notifications

**Technical Dependencies**:
- `app/models/insights/anomaly_detector.rb` (exists)
- `app/controllers/reports_controller.rb` (exists, calls anomaly detector)
- Need: Notification model, dashboard component

**Success Metrics**:
- Users see anomaly alerts within 24 hours of occurrence
- 70%+ users keep anomaly notifications enabled
- Average time-to-awareness of spending spikes reduced by 3+ days

---

### 2. Budget Alert Emails (Priority: P0)

**Business Value**: High
**Effort**: Small
**User Impact**: Email alerts prevent budget overruns

**Current State**:
- `BudgetCategory` model has `percent_of_budget_spent` method
- `BudgetCategory#near_limit?` returns true at 90%+ usage
- `ApplicationMailer` infrastructure exists
- No automated alerts

**What We're Building**:
- Email alert when budget category reaches 80% usage
- Daily background job to check all active budgets
- User preference to customize alert threshold (70%, 80%, 90%)

**Technical Dependencies**:
- `app/models/budget_category.rb` (exists)
- `app/mailers/application_mailer.rb` (exists)
- Need: BudgetAlertMailer, BudgetAlertJob

**Success Metrics**:
- Users receive alerts 12-48 hours before hitting budget limit
- 50%+ users take corrective action after receiving alert
- Budget overruns reduced by 20%

---

### 3. Compare to Last Month Toggle (Priority: P1)

**Business Value**: Medium-High
**Effort**: Small
**User Impact**: Quick period comparison on dashboard

**Current State**:
- `Period` model supports all period types
- `Periodable` concern handles period selection
- Dashboard uses `@period` for all widgets
- Reports page has period comparison logic (`build_previous_period`)
- No quick toggle on dashboard

**What We're Building**:
- Period selector dropdown on dashboard (Current Month, Last Month, Last 30 Days, Custom)
- Comparison badge showing % change vs previous period
- Persist user's preferred default period

**Technical Dependencies**:
- `app/models/period.rb` (exists)
- `app/controllers/concerns/periodable.rb` (exists)
- `app/controllers/pages_controller.rb` (dashboard controller, exists)
- Need: Period selector component, preference storage

**Success Metrics**:
- 60%+ users change period filter within first week
- Average session engagement increases by 15%
- Feature adoption rate: 70%+ users within 30 days

---

### 4. Transaction/Merchant Merge UI (Priority: P1)

**Business Value**: Medium
**Effort**: Medium
**User Impact**: Clean up duplicate data without leaving transaction view

**Current State**:
- `Transaction` model has `merchant_id`
- `Merchant` model exists with `has_many :transactions`
- No merge functionality
- Users manually update each transaction's merchant

**What We're Building**:
- Multi-select transaction rows
- "Merge Transactions" action (updates category, merchant to match selected "primary")
- "Merge Merchants" action (reassigns all transactions from duplicate merchants to primary)
- Undo capability (store previous values for 24 hours)

**Technical Dependencies**:
- `app/models/transaction.rb` (exists)
- `app/models/merchant.rb` (exists)
- `app/controllers/transactions_controller.rb` (exists)
- Need: Bulk update service, merge UI component

**Success Metrics**:
- Average time to deduplicate 10 transactions: < 30 seconds
- 40%+ users with duplicate merchants use merge feature
- Average merchant count per user reduced by 15%

---

### 5. PDF Export (Priority: P2)

**Business Value**: Medium
**Effort**: Extra Small
**User Impact**: Professional reports for sharing/printing

**Current State**:
- Prawn PDF generation code exists in `reports_controller.rb` (lines 816-914)
- Fully implemented `generate_transactions_pdf` method
- Code is commented out (lines 92-97)
- Just needs uncommenting and testing

**What We're Building**:
- Uncomment PDF export code
- Add "prawn" gem to Gemfile
- Test PDF generation with various data sets
- Add PDF download button to Reports page

**Technical Dependencies**:
- `app/controllers/reports_controller.rb` (exists, has commented code)
- Need: Add prawn gem dependency

**Success Metrics**:
- PDF export works for all period types
- 15%+ users export PDF within first month
- Zero PDF generation errors in production

---

### 6. Improve Rule Visibility (Priority: P2)

**Business Value**: Medium
**Effort**: Small
**User Impact**: Increase awareness of automation features

**Current State**:
- `Rule` model fully functional with conditions and actions
- Rules page exists at `/rules` (Settings section)
- No visibility on main dashboard or transaction page
- Users don't discover rules feature

**What We're Building**:
- Dashboard widget showing "X active rules" with link to rules page
- Transaction page: Show applicable rules count in header
- Quick "Create Rule" action from transaction detail view
- Badge on category showing "auto-categorized by rule"

**Technical Dependencies**:
- `app/models/rule.rb` (exists)
- `app/controllers/rules_controller.rb` (exists)
- `app/controllers/transactions_controller.rb` (exists)
- Need: Dashboard widget component, transaction page integration

**Success Metrics**:
- Rule creation rate increases by 50%
- 40%+ users with transactions create at least one rule
- Average time from signup to first rule creation: < 7 days

---

## Prioritized Order

**Sprint 1 (Week 1)**: Foundation + High-Value
1. **PDF Export** (0.5 day) - Easiest win, high satisfaction
2. **Surface Anomaly Alerts** (2 days) - Highest user value
3. **Budget Alert Emails** (1.5 days) - High retention impact

**Sprint 2 (Week 2)**: User Experience + Discovery
4. **Compare to Last Month Toggle** (1 day) - Improves engagement
5. **Improve Rule Visibility** (1.5 days) - Feature discovery
6. **Transaction/Merchant Merge UI** (2.5 days) - Power user feature

**Total**: 9 days (with buffer for testing and polish)

---

## Dependencies & Risks

### Technical Dependencies
- All features leverage existing models and infrastructure
- No new external services required
- No database schema changes (except notification table for anomalies)

### Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Email deliverability issues | Medium | Use existing mailer infrastructure, test with multiple providers |
| PDF generation performance | Low | Already implemented and commented code, just needs testing |
| Merge UI complexity | Medium | Start with simple bulk update, iterate based on feedback |
| Anomaly detection false positives | Medium | Tune thresholds based on user feedback, allow customization |

### Hidden Work
- Localization (i18n) for all new UI strings
- System tests for critical paths (alerts, merge)
- Email template design and testing
- Mobile responsive design for new components
- Analytics tracking for feature adoption
- Documentation updates

---

## Success Criteria

**Epic Complete When**:
- All 6 quick wins deployed to production
- Zero critical bugs in production
- Feature adoption rate: 50%+ users engage with at least 2/6 features within 30 days
- User satisfaction score: 4.2+ / 5 for new features
- No degradation in app performance metrics

**Exit Criteria**:
- All tests passing (unit, integration, system)
- All linting checks passing
- Security audit (Brakeman) clean
- i18n complete for en.yml
- Feature flags enabled for gradual rollout
- Analytics events instrumented

---

## Notes

- All features are designed to work with existing data models
- No breaking changes to API or database schema
- Each feature can be deployed independently
- Rollback plan: Feature flags allow instant disable without code deployment
