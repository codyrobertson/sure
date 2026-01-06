# EPIC: AI Assistant Discoverability

## A. Goals & Context

### Product Goals
- **Increase AI Assistant Usage**: Currently, users don't discover the powerful AI assistant despite 21+ available functions
- **Contextual Discovery**: Surface AI capabilities at the exact moment users need them, integrated into their natural workflows
- **Reduce Time-to-Value**: Help users understand what AI can do for them through examples, not documentation
- **Drive Feature Adoption**: Transform the AI from a hidden chat sidebar into a proactive, discoverable productivity tool

### Technical Goals
- Implement contextual "Ask AI" buttons throughout the application
- Create a reusable AI prompt component system
- Build example prompt suggestions based on page context
- Improve chat sidebar integration and visibility
- Enable deep-linking to chat with pre-filled prompts
- Measure AI engagement metrics (button clicks, prompt usage)

### Business Value
- **User Retention**: Users who engage with AI features have higher retention rates
- **Product Differentiation**: AI-powered personal finance is a key differentiator
- **User Delight**: Proactive, contextual AI creates "wow" moments
- **Reduced Support Load**: AI can answer questions users would otherwise ask support

### Current State Analysis
The application has a powerful AI assistant with comprehensive capabilities:

**21 AI Functions Available:**
1. `get_transactions` - Search and filter transactions
2. `get_accounts` - Retrieve account information
3. `get_balance_sheet` - Calculate net worth
4. `get_income_statement` - Analyze income & expenses
5. `get_cash_flow` - Analyze cash flow & sustainability
6. `categorize_transactions` - Auto-categorize transactions
7. `tag_transactions` - Apply tags to transactions
8. `update_transactions` - Modify transaction data
9. `create_category` - Create new categories
10. `update_category` - Modify categories
11. `delete_category` - Remove categories
12. `create_tag` - Create new tags
13. `create_rule` - Set up automation rules
14. `find_related_transactions` - Find similar transactions
15. `get_recurring_transactions` - Identify recurring patterns
16. `generate_time_series_chart` - Time-based visualizations
17. `generate_donut_chart` - Category breakdowns
18. `generate_sankey_chart` - Cash flow visualizations
19. `generate_account_balance_chart` - Account balance trends
20. `suggest_options` - Get AI recommendations
21. `web_search` - Search external information

**Current Implementation:**
- AI assistant lives in a collapsible right sidebar (desktop) or bottom nav (mobile)
- Chat UI shows greeting with 3 random smart suggestions on first load
- Smart suggestions generated via `Chat::SuggestionGenerator` (cached 24h)
- Fallback suggestions available when generator fails
- No contextual entry points throughout the app
- Users must navigate to chat explicitly

**Constraints**
- Must follow Rails conventions (minimal dependencies, Hotwire-first)
- Must use ViewComponents for reusable UI elements
- Must respect existing design system (`app/assets/tailwind/maybe-design-system.css`)
- Must work on mobile and desktop
- Must maintain performance (no N+1 queries)
- i18n required for all user-facing strings

### Assumptions
- Users don't know what AI can do for them until shown
- Contextual prompts are more effective than generic suggestions
- Visual prominence increases feature discovery
- Pre-filled prompts reduce friction to engagement
- Users are more likely to engage with AI when it's relevant to their current task

### Questions / Missing Information
1. **Analytics**: Do we have analytics to track AI engagement currently?
2. **User Research**: Have users been asked about AI discoverability issues?
3. **Performance Budget**: What's acceptable for additional DOM elements on key pages?
4. **Mobile Strategy**: Should mobile have different discoverability patterns?
5. **A/B Testing**: Should we A/B test different prompt placements?
6. **Onboarding**: Should new users see AI tooltips/tours?

---

## B. Phase Plan

### Phase 1: Foundations & Infrastructure (Sprint 1)
**Goal**: Build reusable components and establish patterns for AI discoverability

**In-Scope:**
- Create `AskAI` ViewComponent for contextual AI buttons
- Build prompt suggestion system based on page context
- Implement deep-linking to chat with pre-filled prompts
- Add contextual AI buttons to 3-4 high-traffic pages
- Update chat sidebar UI for better visibility

**Out-of-Scope:**
- AI onboarding flows
- Advanced analytics/tracking
- AI command palette
- Proactive AI notifications

**Exit Criteria:**
- `AskAI` component tested and documented
- Deep-linking works from any page to chat
- At least 3 pages have contextual AI buttons
- Chat sidebar shows contextual prompts
- All new strings i18n-enabled

**Timeline**: 1 sprint (2 weeks)

---

### Phase 2: Broad Integration (Sprint 2)
**Goal**: Expand AI discoverability to all major workflows

**In-Scope:**
- Add AI buttons to all primary pages (accounts, transactions, reports, budgets)
- Create page-specific prompt libraries
- Implement "Related Prompts" in chat after responses
- Add AI suggestions to empty states
- Build prompt templates for common tasks

**Out-of-Scope:**
- ML-based prompt personalization
- Voice/audio AI interactions
- AI agents/autonomous actions
- Third-party integrations

**Exit Criteria:**
- All major pages have contextual AI entry points
- Empty states suggest relevant AI actions
- Chat shows 3+ related prompts after each response
- Prompt templates documented

**Timeline**: 1 sprint (2 weeks)

---

### Phase 3: Enhancement & Optimization (Sprint 3)
**Goal**: Refine UX, add polish, measure impact

**In-Scope:**
- Add engagement analytics (button clicks, prompt usage)
- Implement AI command palette (Cmd+K)
- Add tooltips/hints for first-time AI users
- Optimize mobile AI experience
- A/B test prompt placements

**Out-of-Scope:**
- AI fine-tuning
- Custom AI model training
- Multi-modal AI (image/voice)
- AI API for third-party apps

**Exit Criteria:**
- Analytics dashboard showing AI engagement
- Command palette functional
- Mobile experience polished
- A/B test results analyzed
- Documentation complete

**Timeline**: 1 sprint (2 weeks)

---

## C. Epics & Tasks

### EPIC-1: Contextual AI Button Component
**Objective**: Build a reusable ViewComponent that surfaces contextual "Ask AI" buttons throughout the app, making AI accessible from any workflow.

**User Impact**: Users can instantly ask AI questions relevant to their current context without navigating away. Reduces friction from 3 clicks (navigate to chat, open sidebar, type prompt) to 1 click.

**Tech Scope:**
- New ViewComponent: `app/components/UI/ask_ai_button.rb`
- Stimulus controller: `app/javascript/controllers/ask_ai_controller.js`
- Deep-link routing: `ChatsController#new` with `prompt` param
- i18n keys for button labels and tooltips
- Design system integration (button variants, icons)

**Dependencies:**
- Existing chat infrastructure
- Design system components (DS::Button)
- Turbo Frame support

**Done-When:**
- Component renders with variants: button, link, menu-item
- Clicking button opens chat with pre-filled prompt
- Works on mobile and desktop
- Tested with fixtures
- i18n complete
- Lookbook preview created

**Docs Required:**
- Component API documentation in component file
- Example usage in Lookbook
- Update ARCHITECTURE.md with component patterns

---

### EPIC-2: Page-Context Prompt System
**Objective**: Build a system that generates smart, contextual AI prompt suggestions based on the current page, user data, and available AI functions.

**User Impact**: Users see relevant AI prompts tailored to their current task (e.g., "Categorize uncategorized transactions" on the transactions page when uncategorized items exist).

**Tech Scope:**
- Helper module: `app/helpers/ai_prompts_helper.rb`
- Context classes: `app/models/ai/prompt_context/*.rb`
- Prompt template system with interpolation
- Page-specific prompt generators:
  - `AccountsPromptContext`
  - `TransactionsPromptContext`
  - `ReportsPromptContext`
  - `BudgetsPromptContext`
- Caching strategy for expensive prompts

**Dependencies:**
- User data (accounts, transactions, categories, tags)
- AI function metadata
- Existing `smart_chat_suggestions` helper

**Done-When:**
- Each major page has 3-5 contextual prompts
- Prompts adapt based on user data state
- Helper methods documented and tested
- Prompts respect data availability (e.g., don't suggest analysis if no transactions)
- i18n complete with interpolation support

**Docs Required:**
- API documentation for prompt context system
- Guide for adding prompts to new pages
- Prompt template syntax reference

---

### EPIC-3: Deep-Link Chat Integration
**Objective**: Enable deep-linking from anywhere in the app to the chat sidebar with pre-filled prompts, allowing seamless context transitions.

**User Impact**: Users click contextual AI buttons and immediately see chat open with their question ready—zero typing required for common tasks.

**Tech Scope:**
- Update `ChatsController#create` to handle `prompt` param
- Update `ChatsController#new` to pre-fill chat form
- Turbo Frame navigation to chat sidebar
- URL parameter handling: `/chats/new?prompt=...`
- Mobile: open chat page, desktop: open sidebar + scroll
- Handle sidebar collapsed state

**Dependencies:**
- Existing chat routing
- Turbo Frame `chat_frame`
- `app-layout` Stimulus controller

**Done-When:**
- URL with `?prompt=` opens chat with pre-filled text
- Works from any page context
- Desktop: opens/expands right sidebar automatically
- Mobile: navigates to chat page
- Prompt text properly URL-encoded/decoded
- Maintains chat history

**Docs Required:**
- Deep-link API documentation
- Examples of constructing prompt URLs
- Update ARCHITECTURE.md with navigation patterns

---

### EPIC-4: Enhanced Chat Sidebar UI
**Objective**: Improve the chat sidebar's visibility, accessibility, and contextual awareness to make AI feel integrated rather than bolted-on.

**User Impact**: Users see relevant prompts in chat based on the page they're viewing. The sidebar feels connected to their workflow, not separate.

**Tech Scope:**
- Update `app/views/chats/_ai_greeting.html.erb`
- Add page context awareness to greeting
- Show page-specific prompts in sidebar
- Add "Examples for this page" section
- Improve empty state messaging
- Add visual indicator when sidebar has contextual suggestions

**Dependencies:**
- Page-context prompt system (EPIC-2)
- Existing chat view templates
- `app-layout` controller state

**Done-When:**
- Chat greeting shows page-aware prompts
- "Examples for this page" section renders on all major pages
- Empty chat shows different prompts per page
- Visual polish complete (icons, spacing, colors)
- i18n complete
- Works on mobile and desktop

**Docs Required:**
- Chat sidebar component documentation
- Guide for adding page-specific greetings

---

## D. Units of Work (UOW)

### EPIC-1: Contextual AI Button Component

**Task T1-1: Create AskAI ViewComponent**
- Belongs to: EPIC-1
- Description: Build the core ViewComponent for contextual AI buttons with support for multiple variants and customization options
- Acceptance Criteria:
  - Component accepts `prompt`, `variant`, `icon`, `class` parameters
  - Renders as button, link, or menu item based on variant
  - Uses design system tokens
  - Includes Stimulus controller for interaction
  - Works with Turbo Frames
- Required Docs: Component API, usage examples

**UOW Units:**

- **U1-1 — Create AskAI Component Structure**
  - Type: frontend
  - Exact Action: Create `/Users/Cody/code_projects/sure/app/components/UI/ask_ai_button.rb` ViewComponent with initializer accepting `prompt:`, `variant:` (default: :button), `icon:` (default: "sparkles"), `label:`, `class:` parameters
  - Estimate: 2 hours
  - Dependencies: None
  - Acceptance Checks:
    - File created with proper ViewComponent inheritance
    - Initializer accepts all parameters
    - Basic render method defined

- **U1-2 — Create AskAI Component Template**
  - Type: frontend
  - Exact Action: Create `/Users/Cody/code_projects/sure/app/components/UI/ask_ai_button.html.erb` with conditional rendering for button/link/menu-item variants using DS::Button and DS::Link components
  - Estimate: 2 hours
  - Dependencies: U1-1
  - Acceptance Checks:
    - Template renders correct HTML for each variant
    - Uses design system components
    - Includes data attributes for Stimulus controller
    - Icon renders using `icon` helper

- **U1-3 — Create AskAI Stimulus Controller**
  - Type: frontend
  - Exact Action: Create `/Users/Cody/code_projects/sure/app/javascript/controllers/ask_ai_controller.js` with `openChat` action that navigates to chat with prompt parameter, handles sidebar state, and scrolls chat into view
  - Estimate: 3 hours
  - Dependencies: U1-2
  - Acceptance Checks:
    - Controller handles click events
    - Constructs proper URL with encoded prompt
    - Opens/expands right sidebar on desktop
    - Navigates to chat page on mobile
    - Scrolls chat into view

- **U1-4 — Add i18n Strings for AskAI**
  - Type: frontend
  - Exact Action: Add i18n keys to `/Users/Cody/code_projects/sure/config/locales/en.yml` under `components.ask_ai_button`: `default_label`, `tooltip`, `aria_label`
  - Estimate: 1 hour
  - Dependencies: U1-1
  - Acceptance Checks:
    - Keys added with descriptive values
    - Component uses i18n helper
    - No hardcoded English strings

- **U1-5 — Create AskAI Lookbook Preview**
  - Type: frontend
  - Exact Action: Create `/Users/Cody/code_projects/sure/test/components/previews/ask_ai_button_preview.rb` with examples of all variants, custom prompts, and different styling options
  - Estimate: 1 hour
  - Dependencies: U1-2, U1-3
  - Acceptance Checks:
    - Preview shows all component variants
    - Examples demonstrate common use cases
    - Preview accessible via Lookbook

- **U1-6 — Write AskAI Component Tests**
  - Type: tests
  - Exact Action: Create `/Users/Cody/code_projects/sure/test/components/UI/ask_ai_button_test.rb` with tests for rendering, parameter handling, and variant switching
  - Estimate: 2 hours
  - Dependencies: U1-2
  - Acceptance Checks:
    - Tests cover all variants
    - Parameter handling tested
    - Edge cases covered (nil prompt, invalid variant)
    - All tests pass

---

**Task T1-2: Implement Deep-Link Chat Routing**
- Belongs to: EPIC-1
- Description: Update ChatsController to accept and handle prompt parameters from deep links
- Acceptance Criteria:
  - `/chats/new?prompt=text` opens chat with pre-filled prompt
  - Desktop opens right sidebar automatically
  - Mobile navigates to chat page
  - URL encoding/decoding works properly
  - Maintains existing chat functionality
- Required Docs: Deep-link API documentation

**UOW Units:**

- **U1-7 — Update ChatsController New Action**
  - Type: backend
  - Exact Action: Modify `/Users/Cody/code_projects/sure/app/controllers/chats_controller.rb` `new` action to accept `params[:prompt]` and pass to view as `@initial_prompt`
  - Estimate: 1 hour
  - Dependencies: None
  - Acceptance Checks:
    - Controller accepts prompt parameter
    - Parameter sanitized and passed to view
    - Existing functionality unchanged

- **U1-8 — Update Chat New View Template**
  - Type: frontend
  - Exact Action: Modify `/Users/Cody/code_projects/sure/app/views/chats/new.html.erb` to pre-fill chat form with `@initial_prompt` if present
  - Estimate: 1 hour
  - Dependencies: U1-7
  - Acceptance Checks:
    - Form textarea pre-filled with initial prompt
    - Empty when no prompt provided
    - Focus on textarea after load

- **U1-9 — Add Auto-Expand Sidebar Logic**
  - Type: frontend
  - Exact Action: Update `/Users/Cody/code_projects/sure/app/javascript/controllers/app_layout_controller.js` to auto-expand right sidebar when navigating to chat with prompt parameter
  - Estimate: 2 hours
  - Dependencies: U1-8
  - Acceptance Checks:
    - Sidebar expands when prompt in URL
    - Only applies to desktop
    - Smooth transition animation
    - Updates user preference

- **U1-10 — Test Deep-Link Navigation**
  - Type: tests
  - Exact Action: Add system tests to `/Users/Cody/code_projects/sure/test/system/chats_test.rb` for deep-link navigation from various pages
  - Estimate: 2 hours
  - Dependencies: U1-7, U1-8, U1-9
  - Acceptance Checks:
    - Test clicking ask-ai button opens chat
    - Test prompt pre-filled correctly
    - Test sidebar expansion on desktop
    - Test mobile navigation

---

**Task T1-3: Add AskAI Buttons to Accounts Page**
- Belongs to: EPIC-1
- Description: Integrate contextual AI buttons into the accounts index page
- Acceptance Criteria:
  - "Ask AI about my accounts" button in page header
  - Individual account cards have "Ask about this account" action
  - Prompts contextual to account data
  - i18n complete
- Required Docs: Usage example in accounts view

**UOW Units:**

- **U1-11 — Add Header AskAI Button to Accounts**
  - Type: frontend
  - Exact Action: Modify `/Users/Cody/code_projects/sure/app/views/accounts/index.html.erb` header section to add AskAI button with prompt "Analyze my account balances and spending patterns"
  - Estimate: 1 hour
  - Dependencies: U1-2, U1-3
  - Acceptance Checks:
    - Button renders in header
    - Uses primary variant
    - Mobile-friendly positioning
    - Prompt opens chat correctly

- **U1-12 — Add Account-Specific AI Helper**
  - Type: backend
  - Exact Action: Add method `account_ai_prompts(account)` to `/Users/Cody/code_projects/sure/app/helpers/accounts_helper.rb` returning array of contextual prompts based on account type, balance, recent activity
  - Estimate: 2 hours
  - Dependencies: None
  - Acceptance Checks:
    - Returns 3-5 relevant prompts per account
    - Prompts vary by account type (checking vs credit card)
    - Handles edge cases (no transactions, negative balance)

- **U1-13 — Add AI Action to Account Dropdown Menu**
  - Type: frontend
  - Exact Action: Find account card menu component and add "Ask AI" menu item using AskAI component with variant=menu-item
  - Estimate: 2 hours
  - Dependencies: U1-2, U1-12
  - Acceptance Checks:
    - Menu item appears in account card dropdown
    - Shows sparkles icon
    - Prompt includes account name
    - Works for all account types

- **U1-14 — Add i18n for Accounts AI Prompts**
  - Type: frontend
  - Exact Action: Add i18n keys to `/Users/Cody/code_projects/sure/config/locales/en.yml` under `accounts.ai_prompts`: `header_prompt`, `analyze_account`, `compare_accounts`, etc.
  - Estimate: 1 hour
  - Dependencies: U1-12
  - Acceptance Checks:
    - All prompts use i18n
    - Interpolation works (account names)
    - No hardcoded strings

---

**Task T1-4: Add AskAI Buttons to Transactions Page**
- Belongs to: EPIC-1
- Description: Integrate contextual AI buttons into the transactions index page
- Acceptance Criteria:
  - Header button for transaction analysis
  - Bulk action menu includes "Ask AI about selected"
  - Empty state suggests AI categorization
  - Search results show AI insights option
- Required Docs: Usage example in transactions view

**UOW Units:**

- **U1-15 — Add Header AskAI Button to Transactions**
  - Type: frontend
  - Exact Action: Modify `/Users/Cody/code_projects/sure/app/views/transactions/index.html.erb` header to add AskAI button next to existing actions
  - Estimate: 1 hour
  - Dependencies: U1-2, U1-3
  - Acceptance Checks:
    - Button renders in header actions area
    - Doesn't break mobile layout
    - Default prompt: "Help me analyze my recent spending"

- **U1-16 — Create Transactions AI Helper**
  - Type: backend
  - Exact Action: Create `/Users/Cody/code_projects/sure/app/helpers/transactions_ai_helper.rb` with methods for contextual prompts based on search filters, selected transactions, uncategorized count
  - Estimate: 3 hours
  - Dependencies: None
  - Acceptance Checks:
    - `transaction_list_prompts(search)` returns relevant prompts
    - `bulk_transaction_prompts(transactions)` for selected items
    - `uncategorized_prompts(count)` when uncategorized exist
    - Handles empty states

- **U1-17 — Add AI to Bulk Actions Menu**
  - Type: frontend
  - Exact Action: Modify `/Users/Cody/code_projects/sure/app/views/transactions/_selection_bar.html.erb` to add "Ask AI" option that uses selected transaction IDs in prompt
  - Estimate: 2 hours
  - Dependencies: U1-2, U1-16
  - Acceptance Checks:
    - Menu item appears when transactions selected
    - Prompt includes transaction count
    - Passes transaction IDs to chat context

- **U1-18 — Add AI to Empty State**
  - Type: frontend
  - Exact Action: Modify `/Users/Cody/code_projects/sure/app/views/entries/_empty.html.erb` to show AI suggestion buttons when no transactions match filters
  - Estimate: 1 hour
  - Dependencies: U1-2
  - Acceptance Checks:
    - Shows 2-3 helpful AI prompts
    - Examples: "Help me set up categories", "Import transactions"
    - i18n complete

- **U1-19 — Add i18n for Transactions AI**
  - Type: frontend
  - Exact Action: Add comprehensive i18n keys to `/Users/Cody/code_projects/sure/config/locales/en.yml` under `transactions.ai_prompts`
  - Estimate: 1 hour
  - Dependencies: U1-16
  - Acceptance Checks:
    - All prompts i18n-enabled
    - Pluralization works correctly
    - Interpolation for counts and dates

---

### EPIC-2: Page-Context Prompt System

**Task T2-1: Build Prompt Context Framework**
- Belongs to: EPIC-2
- Description: Create the core framework for generating contextual AI prompts based on page and user data
- Acceptance Criteria:
  - Base context class with common methods
  - Page-specific context classes
  - Prompt template system with interpolation
  - Caching strategy implemented
- Required Docs: Prompt context API documentation

**UOW Units:**

- **U2-1 — Create Base Prompt Context Class**
  - Type: backend
  - Exact Action: Create `/Users/Cody/code_projects/sure/app/models/ai/prompt_context/base.rb` with abstract methods `prompts`, `available?`, template rendering, and caching logic
  - Estimate: 3 hours
  - Dependencies: None
  - Acceptance Checks:
    - Base class defines interface
    - Template interpolation works
    - Caching uses Rails cache with 1-hour TTL
    - Handles missing data gracefully

- **U2-2 — Create Accounts Prompt Context**
  - Type: backend
  - Exact Action: Create `/Users/Cody/code_projects/sure/app/models/ai/prompt_context/accounts_context.rb` that analyzes user accounts and generates 5-7 contextual prompts
  - Estimate: 3 hours
  - Dependencies: U2-1
  - Acceptance Checks:
    - Prompts vary based on account types
    - Considers account balances, recent syncs
    - Example: "Compare my checking vs savings growth"
    - Returns empty array if no accounts

- **U2-3 — Create Transactions Prompt Context**
  - Type: backend
  - Exact Action: Create `/Users/Cody/code_projects/sure/app/models/ai/prompt_context/transactions_context.rb` analyzing transaction data, categories, tags, date ranges
  - Estimate: 4 hours
  - Dependencies: U2-1
  - Acceptance Checks:
    - Prompts based on uncategorized count
    - Suggests categorization if 10+ uncategorized
    - Considers date range of visible transactions
    - Example: "Categorize my 47 uncategorized transactions"

- **U2-4 — Create Reports Prompt Context**
  - Type: backend
  - Exact Action: Create `/Users/Cody/code_projects/sure/app/models/ai/prompt_context/reports_context.rb` for reports page prompts
  - Estimate: 2 hours
  - Dependencies: U2-1
  - Acceptance Checks:
    - Suggests income/expense analysis
    - Net worth trends
    - Cash flow analysis
    - Example: "Show me my spending trends over the last 6 months"

- **U2-5 — Create Budgets Prompt Context**
  - Type: backend
  - Exact Action: Create `/Users/Cody/code_projects/sure/app/models/ai/prompt_context/budgets_context.rb` for budget-related prompts
  - Estimate: 2 hours
  - Dependencies: U2-1
  - Acceptance Checks:
    - Prompts for budget setup if none exist
    - Budget vs actual analysis
    - Category overspend alerts
    - Example: "Help me create a budget based on my spending"

- **U2-6 — Create AI Prompts Helper Module**
  - Type: backend
  - Exact Action: Create `/Users/Cody/code_projects/sure/app/helpers/ai_prompts_helper.rb` with method `contextual_ai_prompts(page)` that instantiates correct context class and returns prompts
  - Estimate: 2 hours
  - Dependencies: U2-1, U2-2, U2-3, U2-4, U2-5
  - Acceptance Checks:
    - Returns appropriate prompts for each page
    - Handles unknown pages gracefully
    - Caches results per user + page
    - Falls back to generic prompts

- **U2-7 — Write Prompt Context Tests**
  - Type: tests
  - Exact Action: Create test files for each context class in `/Users/Cody/code_projects/sure/test/models/ai/prompt_context/` testing prompt generation logic
  - Estimate: 3 hours
  - Dependencies: U2-2, U2-3, U2-4, U2-5
  - Acceptance Checks:
    - Tests cover various data states
    - Edge cases tested (no data, lots of data)
    - Caching behavior verified
    - All tests pass

---

**Task T2-2: Integrate Prompts into Views**
- Belongs to: EPIC-2
- Description: Update view templates to display contextual prompts
- Acceptance Criteria:
  - All major pages show contextual prompts
  - Prompts displayed as chips/buttons
  - Mobile and desktop layouts work
  - i18n complete
- Required Docs: View integration examples

**UOW Units:**

- **U2-8 — Add Prompt Section to Accounts Page**
  - Type: frontend
  - Exact Action: Add contextual prompt section below header in `/Users/Cody/code_projects/sure/app/views/accounts/index.html.erb` showing 3-5 prompt chips
  - Estimate: 2 hours
  - Dependencies: U2-2, U2-6, U1-2
  - Acceptance Checks:
    - Prompts render as clickable chips
    - Uses AskAI component
    - Responsive layout (scrollable on mobile)
    - Shows sparkles icon

- **U2-9 — Add Prompt Section to Transactions Page**
  - Type: frontend
  - Exact Action: Add contextual prompt section to `/Users/Cody/code_projects/sure/app/views/transactions/index.html.erb` above transaction list
  - Estimate: 2 hours
  - Dependencies: U2-3, U2-6, U1-2
  - Acceptance Checks:
    - Prompts adapt to search filters
    - Different prompts when uncategorized exist
    - Mobile-friendly horizontal scroll

- **U2-10 — Add Prompts to Reports Page**
  - Type: frontend
  - Exact Action: Add AI prompt section to reports page showing analysis suggestions
  - Estimate: 2 hours
  - Dependencies: U2-4, U2-6, U1-2
  - Acceptance Checks:
    - Prompts relevant to financial reports
    - Chart generation suggestions
    - Time period analysis options

- **U2-11 — Add Prompts to Budgets Page**
  - Type: frontend
  - Exact Action: Add AI prompts to budgets page for budget creation and analysis
  - Estimate: 2 hours
  - Dependencies: U2-5, U2-6, U1-2
  - Acceptance Checks:
    - Setup prompts if no budgets
    - Analysis prompts if budgets exist
    - Overspend alerts with AI help

- **U2-12 — Add i18n for All Prompt Templates**
  - Type: frontend
  - Exact Action: Add comprehensive i18n keys to `/Users/Cody/code_projects/sure/config/locales/en.yml` for all prompt templates under `ai.prompts.*`
  - Estimate: 2 hours
  - Dependencies: U2-2, U2-3, U2-4, U2-5
  - Acceptance Checks:
    - All prompts use i18n
    - Interpolation works for dynamic values
    - Fallback strings defined

---

### EPIC-3: Deep-Link Chat Integration

**Task T3-1: Enhance Chat Controller**
- Belongs to: EPIC-3
- Description: Extend chat controller to handle deep-link parameters and maintain context
- Acceptance Criteria:
  - Accepts prompt and context parameters
  - Maintains chat history
  - Handles URL encoding properly
  - Works with Turbo navigation
- Required Docs: Deep-link parameter reference

**UOW Units:**

- **U3-1 — Add Context Parameter Handling**
  - Type: backend
  - Exact Action: Update `/Users/Cody/code_projects/sure/app/controllers/chats_controller.rb` to accept `params[:context]` (page, filters, selected_ids) and store in session
  - Estimate: 2 hours
  - Dependencies: U1-7
  - Acceptance Checks:
    - Context stored in session
    - Available to AI functions
    - Properly sanitized
    - Doesn't break existing functionality

- **U3-2 — Create Chat URL Helper**
  - Type: backend
  - Exact Action: Add helper method `chat_with_prompt_url(prompt, context: {})` to `/Users/Cody/code_projects/sure/app/helpers/chats_helper.rb` that constructs properly encoded URLs
  - Estimate: 1 hour
  - Dependencies: None
  - Acceptance Checks:
    - Generates valid URLs
    - Encodes special characters
    - Handles long prompts (URL length)
    - Works with context hash

- **U3-3 — Update AskAI Component to Use Helper**
  - Type: frontend
  - Exact Action: Modify `/Users/Cody/code_projects/sure/app/components/UI/ask_ai_button.rb` to use `chat_with_prompt_url` helper
  - Estimate: 1 hour
  - Dependencies: U3-2, U1-1
  - Acceptance Checks:
    - Uses helper for URL generation
    - Passes context correctly
    - Existing functionality preserved

- **U3-4 — Test Deep-Link Encoding**
  - Type: tests
  - Exact Action: Add tests to `/Users/Cody/code_projects/sure/test/helpers/chats_helper_test.rb` for URL encoding edge cases
  - Estimate: 2 hours
  - Dependencies: U3-2
  - Acceptance Checks:
    - Tests special characters
    - Tests long prompts
    - Tests context serialization
    - All tests pass

---

### EPIC-4: Enhanced Chat Sidebar UI

**Task T4-1: Page-Aware Chat Greeting**
- Belongs to: EPIC-4
- Description: Update chat greeting to show page-specific context and prompts
- Acceptance Criteria:
  - Greeting message adapts to current page
  - Shows page-specific example prompts
  - Visual indicator of page awareness
  - i18n complete
- Required Docs: Chat greeting customization guide

**UOW Units:**

- **U4-1 — Update Chat Greeting Partial**
  - Type: frontend
  - Exact Action: Modify `/Users/Cody/code_projects/sure/app/views/chats/_ai_greeting.html.erb` to accept `page_context` parameter and show page-aware greeting
  - Estimate: 2 hours
  - Dependencies: U2-6
  - Acceptance Checks:
    - Greeting changes based on page
    - Shows page icon/name
    - Smooth transition between pages
    - Fallback to generic greeting

- **U4-2 — Add Page Context to Application Controller**
  - Type: backend
  - Exact Action: Add `@current_page_context` to `/Users/Cody/code_projects/sure/app/controllers/application_controller.rb` based on controller/action
  - Estimate: 2 hours
  - Dependencies: None
  - Acceptance Checks:
    - Context set for all major pages
    - Available in views
    - Includes page name and type
    - Performance impact minimal

- **U4-3 — Create "Examples for This Page" Section**
  - Type: frontend
  - Exact Action: Add new section to chat greeting showing 3-5 prompts specific to current page with clear heading "Examples for this page"
  - Estimate: 2 hours
  - Dependencies: U4-1, U2-6
  - Acceptance Checks:
    - Section renders below greeting
    - Uses contextual prompts from helper
    - Visually distinct from general prompts
    - Scrollable if many prompts

- **U4-4 — Add Visual Page Indicator**
  - Type: frontend
  - Exact Action: Add visual indicator (icon + page name) to top of chat sidebar showing current page context
  - Estimate: 2 hours
  - Dependencies: U4-2
  - Acceptance Checks:
    - Shows page icon and name
    - Positioned at top of sidebar
    - Updates when page changes
    - Clicking returns to page

- **U4-5 — Add i18n for Page-Aware Greetings**
  - Type: frontend
  - Exact Action: Add i18n keys to `/Users/Cody/code_projects/sure/config/locales/en.yml` for page-specific greetings under `chats.greetings.*`
  - Estimate: 1 hour
  - Dependencies: U4-1
  - Acceptance Checks:
    - Greetings for each page type
    - Interpolation for user name
    - Fallback greeting defined

---

**Task T4-2: Improve Chat Sidebar Visual Design**
- Belongs to: EPIC-4
- Description: Polish the chat sidebar UI for better visibility and engagement
- Acceptance Criteria:
  - Improved color contrast
  - Better prompt chip design
  - Clearer AI avatar/branding
  - Responsive improvements
- Required Docs: Design system updates

**UOW Units:**

- **U4-6 — Redesign Prompt Chips**
  - Type: frontend
  - Exact Action: Update prompt chip styling in greeting and throughout chat to use new design: larger touch targets, hover states, icon placement
  - Estimate: 2 hours
  - Dependencies: None
  - Acceptance Checks:
    - Chips have 44px min height (accessibility)
    - Clear hover/active states
    - Icon on left, text wraps properly
    - Uses design system tokens

- **U4-7 — Improve AI Avatar Design**
  - Type: frontend
  - Exact Action: Update `/Users/Cody/code_projects/sure/app/views/chats/_ai_avatar.html.erb` with improved visual design (larger, more prominent, animated)
  - Estimate: 2 hours
  - Dependencies: None
  - Acceptance Checks:
    - Avatar more visually prominent
    - Subtle animation on load
    - Consistent size across contexts
    - Works in dark mode

- **U4-8 — Add Empty State Improvements**
  - Type: frontend
  - Exact Action: Enhance chat empty state with better visuals, clearer messaging, and featured prompts
  - Estimate: 2 hours
  - Dependencies: U4-1
  - Acceptance Checks:
    - Empty state inviting and clear
    - Shows 3 featured prompts
    - Includes getting started tips
    - i18n complete

- **U4-9 — Improve Mobile Chat Layout**
  - Type: frontend
  - Exact Action: Optimize chat UI for mobile: larger touch targets, better keyboard handling, improved scrolling
  - Estimate: 3 hours
  - Dependencies: None
  - Acceptance Checks:
    - Prompt chips easily tappable
    - Keyboard doesn't obscure input
    - Smooth scrolling to messages
    - Safe area insets respected

---

## E. Delivery & Risk Plan

### Sprint 1 Mapping

**Sprint 1 Theme**: Foundation & First Wins
**Duration**: 2 weeks
**Goal**: Ship core infrastructure and visible improvements to 2-3 high-traffic pages

**Week 1: Component Infrastructure**

Must-Have UOWs:
- U1-1: Create AskAI Component Structure
- U1-2: Create AskAI Component Template
- U1-3: Create AskAI Stimulus Controller
- U1-4: Add i18n Strings for AskAI
- U1-5: Create AskAI Lookbook Preview
- U1-7: Update ChatsController New Action
- U1-8: Update Chat New View Template

Nice-to-Have UOWs:
- U1-6: Write AskAI Component Tests (can complete in Week 2)

Demo Checkpoint: Show AskAI component in Lookbook, demonstrate deep-link navigation

**Week 2: Page Integration**

Must-Have UOWs:
- U1-9: Add Auto-Expand Sidebar Logic
- U1-11: Add Header AskAI Button to Accounts
- U1-12: Add Account-Specific AI Helper
- U1-15: Add Header AskAI Button to Transactions
- U1-16: Create Transactions AI Helper
- U1-19: Add i18n for Transactions AI

Nice-to-Have UOWs:
- U1-6: Write AskAI Component Tests
- U1-10: Test Deep-Link Navigation
- U1-13: Add AI Action to Account Dropdown Menu
- U1-14: Add i18n for Accounts AI Prompts
- U1-17: Add AI to Bulk Actions Menu
- U1-18: Add AI to Empty State

Demo Checkpoint: Show contextual AI buttons on Accounts and Transactions pages, demonstrate full user journey from button click to AI response

---

### Sprint 2 Mapping

**Sprint 2 Theme**: Broad Integration & Context System
**Duration**: 2 weeks
**Goal**: Add AI to all major pages with intelligent context awareness

**Week 1: Context System**

Must-Have UOWs:
- U2-1: Create Base Prompt Context Class
- U2-2: Create Accounts Prompt Context
- U2-3: Create Transactions Prompt Context
- U2-4: Create Reports Prompt Context
- U2-5: Create Budgets Prompt Context
- U2-6: Create AI Prompts Helper Module

Nice-to-Have UOWs:
- U2-7: Write Prompt Context Tests

Demo Checkpoint: Show context system generating prompts for different pages and data states

**Week 2: View Integration**

Must-Have UOWs:
- U2-8: Add Prompt Section to Accounts Page
- U2-9: Add Prompt Section to Transactions Page
- U2-10: Add Prompts to Reports Page
- U2-11: Add Prompts to Budgets Page
- U2-12: Add i18n for All Prompt Templates
- U4-1: Update Chat Greeting Partial
- U4-2: Add Page Context to Application Controller

Nice-to-Have UOWs:
- U2-7: Write Prompt Context Tests
- U4-3: Create "Examples for This Page" Section

Demo Checkpoint: Show complete integration on all major pages with contextual prompts

---

### Sprint 3 Mapping

**Sprint 3 Theme**: Polish, Enhancement & Measurement
**Duration**: 2 weeks
**Goal**: Refine UX, improve mobile experience, add analytics

**Week 1: UI Polish**

Must-Have UOWs:
- U4-3: Create "Examples for This Page" Section
- U4-4: Add Visual Page Indicator
- U4-5: Add i18n for Page-Aware Greetings
- U4-6: Redesign Prompt Chips
- U4-7: Improve AI Avatar Design
- U4-8: Add Empty State Improvements

Nice-to-Have UOWs:
- U4-9: Improve Mobile Chat Layout

Demo Checkpoint: Show polished UI with improved visual design and page awareness

**Week 2: Context & Testing**

Must-Have UOWs:
- U3-1: Add Context Parameter Handling
- U3-2: Create Chat URL Helper
- U3-3: Update AskAI Component to Use Helper
- U4-9: Improve Mobile Chat Layout
- All remaining test UOWs (U1-6, U1-10, U2-7, U3-4)

Nice-to-Have UOWs:
- Additional prompt contexts for edge cases
- Analytics event tracking (separate epic)

Demo Checkpoint: Full feature demo with mobile experience, edge cases handled, tests passing

---

### Critical Path

**Blocking Dependencies Chain:**

1. **U1-1 → U1-2 → U1-3** (AskAI Component): Nothing else can proceed without the core component
2. **U1-7 → U1-8** (Deep-link routing): Required for component functionality
3. **U1-9** (Auto-expand sidebar): Enhances UX but not strictly blocking
4. **U2-1 → U2-2, U2-3, U2-4, U2-5** (Context system): All context classes depend on base class
5. **U2-6** (AI Prompts Helper): Depends on all context classes, required for views
6. **U2-8, U2-9, U2-10, U2-11** (View integration): Depends on helper and component

**Minimum Viable Path** (fastest path to user value):
U1-1 → U1-2 → U1-3 → U1-7 → U1-8 → U1-11 → U1-15 (basic button on 2 pages)

**Recommended Path** (balanced value + quality):
Follow Sprint 1 → Sprint 2 → Sprint 3 sequence

---

### Risks & Hidden Work

#### Risk 1: Performance Impact
**Risk**: Adding AI buttons and context calculations to every page could slow down page loads
**Why it matters**: User experience degrades if pages feel sluggish
**Phase/Epic**: Phase 1, EPIC-1 & EPIC-2
**Mitigation**:
- Implement aggressive caching for prompt contexts (1 hour TTL)
- Use database indexes for common queries (uncategorized count, recent transactions)
- Lazy-load chat sidebar content
- Measure with Rails performance tools
**Impact if ignored**: HIGH - Users abandon slow pages

#### Risk 2: Mobile UX Complexity
**Risk**: Mobile navigation to chat may be jarring, taking users away from their current task
**Why it matters**: Mobile represents significant traffic, poor mobile UX hurts adoption
**Phase/Epic**: Phase 1, EPIC-3
**Mitigation**:
- Consider bottom sheet UI for mobile chat (alternative to full navigation)
- Add "back to [page]" breadcrumb in mobile chat
- Maintain scroll position when returning
- A/B test different mobile patterns
**Impact if ignored**: MEDIUM - Mobile users don't engage with AI

#### Risk 3: Prompt Quality & Relevance
**Risk**: Auto-generated prompts may not resonate with users or may be irrelevant
**Why it matters**: Bad suggestions train users to ignore AI
**Phase/Epic**: Phase 2, EPIC-2
**Mitigation**:
- Start with curated, hand-crafted prompts
- Gather user feedback on prompt usefulness
- A/B test different prompt styles
- Monitor prompt click-through rates
- Build feedback mechanism ("Was this helpful?")
**Impact if ignored**: HIGH - Users learn to ignore AI suggestions

#### Risk 4: Chat Context Loss
**Risk**: Opening chat from a page may not provide enough context to AI for useful responses
**Why it matters**: AI responses seem dumb if lacking context
**Phase/Epic**: Phase 1, EPIC-3
**Mitigation**:
- Pass context parameters (page, filters, selected items) to chat
- Update AI system prompt with page context
- Show context in chat UI ("Based on your Transactions page...")
- Allow users to modify context
**Impact if ignored**: MEDIUM - AI responses less useful than expected

#### Risk 5: i18n Incomplete
**Risk**: With hundreds of new prompts, i18n coverage may be incomplete
**Why it matters**: Non-English users see broken UI
**Phase/Epic**: All phases
**Mitigation**:
- Add i18n as UOW for each task
- Use i18n linting tools
- Automated tests for missing keys
- Interpolation for dynamic content
**Impact if ignored**: MEDIUM - Breaks international user experience

#### Risk 6: Sidebar State Management
**Risk**: Managing sidebar open/closed state across page navigations is complex
**Why it matters**: Users lose context or get confused by sidebar behavior
**Phase/Epic**: Phase 1, EPIC-1 & EPIC-3
**Mitigation**:
- Use `turbo_permanent` for chat frame
- Store sidebar state in user preferences
- Clear rules for when to auto-open/close
- Test extensively with Turbo navigation
**Impact if ignored**: MEDIUM - Confusing user experience

#### Risk 7: URL Length Limits
**Risk**: Long prompts in URL parameters may exceed browser/server limits
**Why it matters**: Feature breaks for complex prompts
**Phase/Epic**: Phase 1, EPIC-3
**Mitigation**:
- Use POST instead of GET for long prompts
- Store prompt in session and pass token
- Truncate prompts over limit with ellipsis
- Show warning to users
**Impact if ignored**: LOW - Edge case but breaks experience

---

### Hidden Work

#### Analytics & Tracking
**What**: Event tracking for AI engagement (button clicks, prompt usage, response quality)
**Estimated Effort**: 1-2 days
**When**: Phase 3
**Why Needed**: Can't measure success without data

#### Error Handling
**What**: Graceful degradation when AI unavailable, context system fails, or prompts can't generate
**Estimated Effort**: 1 day
**When**: Throughout all phases
**Why Needed**: Production reliability

#### Accessibility Audit
**What**: ARIA labels, keyboard navigation, screen reader testing for all new components
**Estimated Effort**: 2-3 days
**When**: End of Phase 1
**Why Needed**: Legal compliance, inclusive design

#### Browser Testing
**What**: Test on Safari, Firefox, mobile browsers for prompt chips, sidebar behavior, deep linking
**Estimated Effort**: 1 day
**When**: End of Phase 1
**Why Needed**: Cross-browser compatibility

#### Dark Mode
**What**: Ensure all new UI elements work in dark mode
**Estimated Effort**: 0.5 days
**When**: Throughout (part of each UOW)
**Why Needed**: Design system requirement

#### Documentation Updates
**What**: Update ARCHITECTURE.md, component docs, API references
**Estimated Effort**: 1 day
**When**: End of each phase
**Why Needed**: Team knowledge, future maintenance

#### Migration Path for Existing Users
**What**: Introduce AI discoverability to existing users who haven't used it (tooltips? tour?)
**Estimated Effort**: 2-3 days (if building tour)
**When**: Phase 3
**Why Needed**: Feature adoption among existing users

#### Load Testing
**What**: Ensure prompt context system performs under load (1000+ concurrent users)
**Estimated Effort**: 1 day
**When**: End of Phase 2
**Why Needed**: Production readiness

---

### Tech Debt

#### TD-1: Prompt Template System
**Debt**: Starting with simple string interpolation; may need more sophisticated template engine later
**Priority**: Low
**Address When**: If prompts become complex with conditional logic
**Estimated Paydown**: 2-3 days to build proper template system

#### TD-2: Context Serialization
**Debt**: Passing context as URL params is simple but limited; may need session-based approach
**Priority**: Medium
**Address When**: Phase 2 if URL limits hit
**Estimated Paydown**: 1 day to implement session tokens

#### TD-3: Prompt Caching Strategy
**Debt**: Simple time-based cache; may need cache invalidation on data changes
**Priority**: Low
**Address When**: If users report stale prompts
**Estimated Paydown**: 2 days for event-based cache invalidation

#### TD-4: Component Testing Strategy
**Debt**: Basic component tests; no visual regression or interaction testing
**Priority**: Low
**Address When**: If UI bugs slip through
**Estimated Paydown**: 2-3 days to add Capybara system tests

#### TD-5: AI Prompt Analytics
**Debt**: No analytics initially; manual tracking needed
**Priority**: High
**Address When**: Phase 3 (included in sprint)
**Estimated Paydown**: 2-3 days for event tracking + dashboard

#### TD-6: Prompt Personalization
**Debt**: All prompts generic; not personalized to user behavior
**Priority**: Low
**Address When**: Future enhancement (post-MVP)
**Estimated Paydown**: 1-2 weeks for ML-based personalization

---

### Recommended Sequencing

**Week 1-2: Sprint 1**
Focus: Ship visible improvements fast
- Build AskAI component
- Add to Accounts and Transactions pages
- Deep-link navigation working
- Demo to stakeholders

**Week 3-4: Sprint 2**
Focus: Broad coverage with smart context
- Build context system
- Add to all major pages
- Page-aware chat sidebar
- Internal alpha testing

**Week 5-6: Sprint 3**
Focus: Polish and measure
- Visual polish
- Mobile optimization
- Analytics integration
- Public beta launch

**Success Metrics**:
- 30%+ of active users click an AI button within first week
- 50%+ of AI interactions come from contextual buttons (not direct chat)
- Average time-to-first-AI-interaction drops by 50%
- AI chat sessions increase by 2-3x

---

## F. Open Questions & Next Steps

### Questions for Product Team
1. What's the target AI engagement rate? (% of users per week)
2. Should we build onboarding flow for first-time AI users?
3. Is there budget for A/B testing infrastructure?
4. Do we want AI prompt feedback collection?

### Questions for Engineering Team
1. Are there performance concerns with additional sidebar content?
2. Should we use Stimulus or React for prompt chips?
3. Is there existing analytics infrastructure we can use?
4. Do we need legal review for AI feature prominence?

### Questions for Design Team
1. Can we get mockups for mobile AI bottom sheet?
2. Should prompt chips match existing design system or new style?
3. Do we need animations for AI discoverability (sparkle effects)?
4. What's the mobile navigation pattern (full page vs modal)?

### Immediate Next Steps
1. **Week -1 (Pre-Sprint)**:
   - Review and approve this epic
   - Design team creates mockups for key components
   - Engineering sets up project board with UOWs
   - Stakeholder alignment meeting

2. **Day 1 of Sprint 1**:
   - Kickoff meeting with full team
   - Assign UOWs to engineers
   - Set up daily standups
   - Begin U1-1 (AskAI component structure)

3. **Mid-Sprint Check-ins**:
   - Demo component in Lookbook (Day 5)
   - First page integration demo (Day 8)
   - Sprint review with stakeholders (Day 10)

---

## G. Success Criteria Summary

**Phase 1 Success**:
- [ ] AskAI component live and tested
- [ ] Deep-linking functional
- [ ] 2+ pages have AI buttons
- [ ] Users can click and get AI help
- [ ] Zero P1 bugs

**Phase 2 Success**:
- [ ] All major pages have AI integration
- [ ] Context system generating smart prompts
- [ ] Chat sidebar page-aware
- [ ] 30%+ engagement rate with AI buttons

**Phase 3 Success**:
- [ ] Mobile experience polished
- [ ] Analytics tracking engagement
- [ ] A/B test insights gathered
- [ ] 2-3x increase in AI usage
- [ ] Documentation complete

**Overall Success**:
AI transforms from hidden feature to core part of user workflow, with majority of AI interactions initiated through contextual buttons rather than direct chat navigation.
