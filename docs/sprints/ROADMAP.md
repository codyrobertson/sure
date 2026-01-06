# Sure Finance - Product Roadmap

## Overview

This roadmap outlines planned improvements to make Sure Finance more useful and engaging for users. Features are organized into epics with sprint-level task breakdowns.

---

## Q1 2026 Roadmap

### Sprint 1: Quick Wins (1 week)
**Goal:** Ship high-impact, low-effort improvements to demonstrate momentum

| Feature | Impact | Effort | Status |
|---------|--------|--------|--------|
| Anomaly Alerts | High | S | Planned |
| Budget Alert Emails | High | S | Planned |
| Period Comparison Toggle | Medium | S | Planned |
| PDF Export | Medium | S | Planned |
| Active Rules Widget | Low | S | Planned |

**Deliverables:**
- [ ] docs/epics/quick-wins-q1.md
- [ ] docs/tasks/quickwins-sprint-1.md

---

### Sprint 2-3: Goals & Savings Tracking (2 weeks)
**Goal:** Add missing savings goals feature - highest user value

| Milestone | Description | Sprint |
|-----------|-------------|--------|
| Goal CRUD | Create, edit, delete savings goals | S2 |
| Dashboard Widget | Progress visualization on dashboard | S2 |
| Account Linking | Link goals to specific accounts | S2 |
| AI Integration | "How am I doing on my goals?" | S3 |
| Forecasting | Projected completion dates | S3 |

**Deliverables:**
- [ ] docs/epics/goals-savings-tracking.md
- [ ] docs/tasks/goals-sprint-1.md
- [ ] docs/tasks/goals-sprint-2.md

---

### Sprint 4-5: Budget Intelligence (2 weeks)
**Goal:** Transform basic budgets into actionable intelligence

| Milestone | Description | Sprint |
|-----------|-------------|--------|
| Budget Dashboard | Real-time budget vs actual | S4 |
| Progress Bars | Visual category-level tracking | S4 |
| Pace Alerts | "On track to overspend by $X" | S4 |
| AI Explanations | Why did I overspend? | S5 |
| Recommendations | AI-suggested budget adjustments | S5 |

**Deliverables:**
- [ ] docs/epics/budget-intelligence.md
- [ ] docs/tasks/budget-sprint-1.md
- [ ] docs/tasks/budget-sprint-2.md

---

### Sprint 6: AI Discoverability (1 week)
**Goal:** Surface the powerful AI assistant throughout the app

| Feature | Location | Priority |
|---------|----------|----------|
| "Ask AI" Buttons | Accounts, Transactions, Categories | P0 |
| Example Prompts | Chat sidebar | P0 |
| Quick Replies | After AI responses | P1 |
| Proactive Insights | Dashboard widget | P1 |

**Deliverables:**
- [ ] docs/epics/ai-discoverability.md
- [ ] docs/tasks/ai-sprint-1.md

---

## Epic Documentation Structure

Each epic follows this structure:

```
docs/
├── epics/
│   ├── goals-savings-tracking.md    # Epic overview, user stories
│   ├── budget-intelligence.md
│   ├── ai-discoverability.md
│   └── quick-wins-q1.md
├── tasks/
│   ├── goals-sprint-1.md            # Sprint-level UOWs
│   ├── goals-sprint-2.md
│   ├── budget-sprint-1.md
│   ├── budget-sprint-2.md
│   ├── ai-sprint-1.md
│   └── quickwins-sprint-1.md
└── sprints/
    └── ROADMAP.md                   # This file
```

---

## Definition of Done

A feature is "Done" when:
- [ ] Code complete and passing tests
- [ ] i18n keys added for all user-facing strings
- [ ] Mobile-responsive (or explicitly scoped out)
- [ ] AI assistant integration (where applicable)
- [ ] Documentation updated (CLAUDE.md if patterns change)
- [ ] Deployed to Docker and verified

---

## Success Metrics

| Epic | Key Metric | Target |
|------|------------|--------|
| Goals | % users with 1+ goal | 40% |
| Budget Intelligence | Budget page visits/week | +50% |
| AI Discoverability | AI conversations/user/week | +100% |
| Quick Wins | User-reported issues | -30% |

---

## Dependencies

| Feature | Depends On |
|---------|------------|
| Goal AI Integration | Goals CRUD complete |
| Budget AI Explanations | Budget Dashboard complete |
| Proactive AI Insights | Anomaly Alerts wired |

---

## Risk Register

| Risk | Mitigation |
|------|------------|
| Scope creep on Goals | Strict MVP definition in sprint docs |
| AI costs increase | Cache common queries, batch operations |
| Mobile not addressed | Explicitly out of scope for Q1 |

---

*Last updated: 2026-01-06*
