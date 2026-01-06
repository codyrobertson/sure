# Sprint 1: AI Discoverability - Foundation & First Wins

## Sprint Overview

**Duration**: 2 weeks (10 working days)
**Theme**: Foundation & First Wins
**Goal**: Ship core infrastructure and visible improvements to 2-3 high-traffic pages

**Success Criteria**:
- AskAI component functional and tested
- Deep-linking from any page to chat works
- Accounts and Transactions pages have contextual AI buttons
- Users can click button → chat opens → AI responds
- All new UI is i18n-enabled
- Zero P1 bugs in production

**Team Capacity Assumptions**:
- 2 frontend engineers (80 hours total)
- 1 backend engineer (40 hours total)
- Velocity: ~80-100 UOW hours per sprint (accounting for meetings, code review, debugging)

---

## Week 1: Component Infrastructure

### Objective
Build the foundational AskAI component and deep-link routing that all future work depends on.

### UOWs - Week 1

---

#### UOW-W1-1: Create AskAI Component Structure
**Type**: Frontend (Component)
**Complexity**: S
**Estimated Effort**: 2 hours
**Owner**: Frontend Engineer 1
**Priority**: CRITICAL

**Description**:
Create the base ViewComponent for contextual AI buttons. This is the foundation that all AI discoverability features will build upon.

**Tasks**:
1. Create file: `/Users/Cody/code_projects/sure/app/components/UI/ask_ai_button.rb`
2. Inherit from `ApplicationComponent`
3. Define initializer accepting parameters:
   - `prompt:` (String, required) - The AI prompt text
   - `variant:` (Symbol, default: `:button`) - Options: `:button`, `:link`, `:menu_item`
   - `icon:` (String, default: `"sparkles"`) - Icon name
   - `label:` (String, optional) - Button text override
   - `class:` (String, optional) - Additional CSS classes
   - `context:` (Hash, optional) - Additional context (page, filters, etc.)
4. Store parameters as instance variables
5. Validate required parameters

**Acceptance Criteria**:
- [ ] File created with proper class definition
- [ ] Inherits from `ApplicationComponent`
- [ ] Initializer accepts all parameters with correct defaults
- [ ] Required parameter validation (raises if `prompt` blank)
- [ ] Instance variables accessible in template
- [ ] No syntax errors

**Files to Create**:
- `/Users/Cody/code_projects/sure/app/components/UI/ask_ai_button.rb`

**Dependencies**: None

**Testing Notes**:
- Manual: `bin/rails console` → `UI::AskAiButton.new(prompt: "test").inspect`
- Unit test created in later UOW

---

#### UOW-W1-2: Create AskAI Component Template
**Type**: Frontend (Component)
**Complexity**: M
**Estimated Effort**: 2 hours
**Owner**: Frontend Engineer 1
**Priority**: CRITICAL

**Description**:
Build the ERB template that renders the AskAI button in different variants using the design system.

**Tasks**:
1. Create file: `/Users/Cody/code_projects/sure/app/components/UI/ask_ai_button.html.erb`
2. Implement conditional rendering based on `@variant`:
   - `:button` → Use `DS::Button` component
   - `:link` → Use `DS::Link` component
   - `:menu_item` → Use `DS::MenuItem` component (if exists, else plain link)
3. Add Stimulus controller data attributes:
   - `data-controller="ask-ai"`
   - `data-action="click->ask-ai#openChat"`
   - `data-ask-ai-prompt-value="<%= @prompt %>"`
   - `data-ask-ai-context-value="<%= @context.to_json %>"`
4. Use `icon(@icon)` helper for icon rendering
5. Handle label logic (use `@label` if present, else default based on variant)
6. Apply custom classes via `@class`

**Acceptance Criteria**:
- [ ] Template renders without errors
- [ ] All three variants render correctly
- [ ] Stimulus data attributes present
- [ ] Icon renders using `icon` helper (NOT `lucide_icon`)
- [ ] Design system components used (DS::Button, DS::Link)
- [ ] Proper HTML semantics (button vs link)
- [ ] Custom classes applied correctly
- [ ] Works in Lookbook preview

**Files to Create**:
- `/Users/Cody/code_projects/sure/app/components/UI/ask_ai_button.html.erb`

**Files to Modify**: None

**Dependencies**: UOW-W1-1

**Design Reference**:
- Use existing `DS::Button` and `DS::Link` patterns
- Primary variant for standalone buttons
- Outline variant for secondary actions
- Icon placement: left side of text

---

#### UOW-W1-3: Create AskAI Stimulus Controller
**Type**: Frontend (JavaScript)
**Complexity**: M
**Estimated Effort**: 3 hours
**Owner**: Frontend Engineer 1
**Priority**: CRITICAL

**Description**:
Build the Stimulus controller that handles clicking AskAI buttons and navigating to chat with the prompt.

**Tasks**:
1. Create file: `/Users/Cody/code_projects/sure/app/javascript/controllers/ask_ai_controller.js`
2. Define values:
   - `prompt` (String)
   - `context` (Object)
3. Implement `openChat` action:
   - Construct chat URL: `/chats/new?prompt=<encoded>`
   - URL-encode prompt text
   - Add context as JSON if present
   - Detect mobile vs desktop
   - Desktop: Navigate to chat in turbo frame + expand sidebar
   - Mobile: Navigate to chat page
4. Integrate with `app-layout` controller:
   - Call `expandRightSidebar()` on desktop
   - Ensure sidebar visible before navigation
5. Handle edge cases:
   - Empty prompt
   - Prompt too long (>2000 chars)
   - Context serialization errors

**Acceptance Criteria**:
- [ ] Controller file created and imports properly
- [ ] Values defined and accessible
- [ ] `openChat` action works on click
- [ ] URL properly encodes special characters
- [ ] Desktop: sidebar expands and shows chat
- [ ] Mobile: navigates to chat page
- [ ] Context passed correctly
- [ ] No console errors
- [ ] Works with Turbo navigation

**Files to Create**:
- `/Users/Cody/code_projects/sure/app/javascript/controllers/ask_ai_controller.js`

**Files to Modify**:
- `/Users/Cody/code_projects/sure/app/javascript/controllers/index.js` (if manual registration needed)

**Dependencies**: UOW-W1-2

**Technical Notes**:
```javascript
// Example structure
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { prompt: String, context: Object }

  openChat(event) {
    event.preventDefault()
    const url = this.buildChatUrl()
    this.navigateToChat(url)
    this.expandSidebarIfDesktop()
  }

  buildChatUrl() {
    // Implementation
  }

  navigateToChat(url) {
    // Turbo navigation logic
  }

  expandSidebarIfDesktop() {
    // Find app-layout controller and call expand
  }
}
```

---

#### UOW-W1-4: Add i18n Strings for AskAI Component
**Type**: Frontend (i18n)
**Complexity**: S
**Estimated Effort**: 1 hour
**Owner**: Frontend Engineer 1
**Priority**: HIGH

**Description**:
Add internationalization keys for all user-facing strings in the AskAI component.

**Tasks**:
1. Open `/Users/Cody/code_projects/sure/config/locales/en.yml`
2. Add new section under `components`:
   ```yaml
   components:
     ask_ai_button:
       default_label: "Ask AI"
       tooltip: "Ask AI for help with this"
       aria_label: "Open AI assistant with suggested question"
       button_label: "Ask AI"
       link_label: "Ask AI about this"
   ```
3. Update component template to use `t()` helper
4. Support label interpolation if needed
5. Test all strings render correctly

**Acceptance Criteria**:
- [ ] i18n keys added to `en.yml`
- [ ] All hardcoded strings removed from component
- [ ] Component uses `t()` helper for labels
- [ ] Tooltip and ARIA labels defined
- [ ] No missing translation errors in logs
- [ ] Strings clear and concise

**Files to Modify**:
- `/Users/Cody/code_projects/sure/config/locales/en.yml`
- `/Users/Cody/code_projects/sure/app/components/UI/ask_ai_button.html.erb`

**Dependencies**: UOW-W1-2

---

#### UOW-W1-5: Create AskAI Lookbook Preview
**Type**: Frontend (Documentation)
**Complexity**: S
**Estimated Effort**: 1 hour
**Owner**: Frontend Engineer 1
**Priority**: MEDIUM

**Description**:
Create Lookbook preview showcasing all AskAI component variants and use cases.

**Tasks**:
1. Create file: `/Users/Cody/code_projects/sure/test/components/previews/ask_ai_button_preview.rb`
2. Define preview class inheriting from `Lookbook::Preview`
3. Create scenarios:
   - `default` - Basic button variant
   - `link_variant` - Link style
   - `menu_item_variant` - Menu item style
   - `custom_prompt` - Long custom prompt example
   - `with_context` - Example with context hash
   - `different_icons` - Show various icon options
4. Add descriptions and notes for each scenario
5. Test in Lookbook UI

**Acceptance Criteria**:
- [ ] Preview file created
- [ ] All variants showcased
- [ ] Examples have descriptive labels
- [ ] Prompts demonstrate real use cases
- [ ] Accessible via `/lookbook` in development
- [ ] Visual examples look correct
- [ ] Interactive (buttons clickable)

**Files to Create**:
- `/Users/Cody/code_projects/sure/test/components/previews/ask_ai_button_preview.rb`

**Dependencies**: UOW-W1-2, UOW-W1-3, UOW-W1-4

**Example Structure**:
```ruby
class AskAiButtonPreview < Lookbook::Preview
  # @param prompt text
  # @param variant select { choices: [button, link, menu_item] }
  def default(prompt: "Analyze my spending", variant: :button)
    render UI::AskAiButton.new(prompt: prompt, variant: variant.to_sym)
  end

  # Button variant with custom icon
  def custom_icon
    render UI::AskAiButton.new(
      prompt: "Show me my net worth trend",
      icon: "trending-up"
    )
  end
end
```

---

#### UOW-W1-6: Update ChatsController for Prompt Parameter
**Type**: Backend
**Complexity**: S
**Estimated Effort**: 1 hour
**Owner**: Backend Engineer
**Priority**: CRITICAL

**Description**:
Modify ChatsController to accept and handle `prompt` parameter from deep links.

**Tasks**:
1. Open `/Users/Cody/code_projects/sure/app/controllers/chats_controller.rb`
2. Update `new` action:
   - Accept `params[:prompt]`
   - Sanitize prompt text (strip, truncate to 5000 chars)
   - Store in `@initial_prompt` instance variable
   - Accept `params[:context]` as JSON string
   - Parse and store in `@initial_context`
3. Add private helper method `sanitize_prompt_param`
4. Handle edge cases (nil, blank, XSS attempts)
5. Don't break existing functionality (new chat without params)

**Acceptance Criteria**:
- [ ] `new` action accepts `prompt` parameter
- [ ] Prompt sanitized and stored in `@initial_prompt`
- [ ] Context parsed and stored in `@initial_context`
- [ ] XSS protection in place
- [ ] Existing functionality unchanged (new chat works)
- [ ] No errors with missing params
- [ ] Prompt truncated if > 5000 chars

**Files to Modify**:
- `/Users/Cody/code_projects/sure/app/controllers/chats_controller.rb`

**Dependencies**: None

**Code Example**:
```ruby
def new
  @chat = Current.user.chats.new(title: "New chat #{Time.current.strftime("%Y-%m-%d %H:%M")}")
  @initial_prompt = sanitize_prompt_param(params[:prompt])
  @initial_context = parse_context_param(params[:context])
end

private

def sanitize_prompt_param(prompt)
  return nil if prompt.blank?
  prompt.to_s.strip.truncate(5000)
end

def parse_context_param(context)
  return {} if context.blank?
  JSON.parse(context)
rescue JSON::ParserError
  {}
end
```

---

#### UOW-W1-7: Update Chat New View with Pre-filled Prompt
**Type**: Frontend (View)
**Complexity**: S
**Estimated Effort**: 1 hour
**Owner**: Frontend Engineer 2
**Priority**: CRITICAL

**Description**:
Modify the chat new view template to pre-fill the chat form with the initial prompt if provided.

**Tasks**:
1. Open `/Users/Cody/code_projects/sure/app/views/chats/new.html.erb`
2. Find chat form textarea/input
3. Set value/content to `@initial_prompt` if present
4. Add auto-focus to textarea when prompt provided
5. Maintain existing behavior when no prompt
6. Show visual indicator that prompt is pre-filled (optional)

**Acceptance Criteria**:
- [ ] Form pre-filled with `@initial_prompt` when present
- [ ] Textarea auto-focuses on load
- [ ] Cursor positioned at end of prompt text
- [ ] Works on mobile and desktop
- [ ] No errors when `@initial_prompt` is nil
- [ ] Existing new chat functionality preserved
- [ ] User can edit pre-filled prompt

**Files to Modify**:
- `/Users/Cody/code_projects/sure/app/views/chats/new.html.erb`

**Dependencies**: UOW-W1-6

**Technical Notes**:
- Use `autofocus: true` on textarea
- May need Stimulus controller for cursor positioning
- Consider UX: should prompt be editable or submitted automatically?
- Decision: Make editable (users should review AI prompts)

---

#### UOW-W1-8: Add Auto-Expand Sidebar Logic
**Type**: Frontend (JavaScript)
**Complexity**: M
**Estimated Effort**: 2 hours
**Owner**: Frontend Engineer 2
**Priority**: HIGH

**Description**:
Update the app-layout controller to automatically expand the right sidebar when navigating to chat with a prompt.

**Tasks**:
1. Open `/Users/Cody/code_projects/sure/app/javascript/controllers/app_layout_controller.js`
2. Add method `expandRightSidebarIfNeeded()`
3. Check URL params for `prompt` parameter
4. If present and on desktop, expand right sidebar
5. Trigger after Turbo navigation completes
6. Smooth animation transition
7. Update user preference (persist sidebar state)
8. Don't auto-expand on mobile

**Acceptance Criteria**:
- [ ] Right sidebar expands when URL has `?prompt=`
- [ ] Only applies to desktop (viewport > 1024px)
- [ ] Smooth animation (uses existing transition)
- [ ] User preference updated in database
- [ ] Doesn't conflict with manual sidebar toggle
- [ ] Works with Turbo navigation
- [ ] Mobile unchanged (full page navigation)

**Files to Modify**:
- `/Users/Cody/code_projects/sure/app/javascript/controllers/app_layout_controller.js`

**Dependencies**: UOW-W1-6, UOW-W1-7

**Technical Notes**:
```javascript
// Add to app_layout_controller.js
connect() {
  // Existing connect logic
  this.expandRightSidebarIfNeeded()
}

expandRightSidebarIfNeeded() {
  const urlParams = new URLSearchParams(window.location.search)
  const hasPrompt = urlParams.has('prompt')
  const isDesktop = window.innerWidth >= 1024

  if (hasPrompt && isDesktop && !this.isRightSidebarExpanded) {
    this.toggleRightSidebar()
  }
}
```

---

#### UOW-W1-9: Manual Testing & Bug Fixes
**Type**: Testing
**Complexity**: M
**Estimated Effort**: 3 hours
**Owner**: Both Frontend Engineers
**Priority**: HIGH

**Description**:
Comprehensive manual testing of Week 1 infrastructure on desktop and mobile, fixing any bugs found.

**Tasks**:
1. Test AskAI component in Lookbook:
   - All variants render correctly
   - Icons display properly
   - Clicking works (opens chat)
2. Test deep-link navigation:
   - Desktop: sidebar expands, prompt pre-fills
   - Mobile: navigates to chat page, prompt pre-fills
3. Test edge cases:
   - Very long prompts
   - Special characters in prompts (quotes, emoji)
   - Empty/blank prompts
   - Context with complex data
4. Browser testing: Chrome, Safari, Firefox
5. Mobile testing: iOS Safari, Android Chrome
6. Fix all bugs found
7. Document any known issues

**Acceptance Criteria**:
- [ ] All variants tested in Lookbook
- [ ] Deep-linking works on desktop
- [ ] Deep-linking works on mobile
- [ ] Edge cases handled gracefully
- [ ] No console errors
- [ ] No visual glitches
- [ ] Tested on 3+ browsers
- [ ] Mobile tested on real devices
- [ ] Bug list documented

**Files to Modify**: Various (bug fixes)

**Dependencies**: UOW-W1-1 through UOW-W1-8

---

### End of Week 1 Demo
**What to Show**:
- AskAI component in Lookbook (all variants)
- Click button → chat opens with prompt (desktop)
- Click button → navigate to chat (mobile)
- Edit prompt before submitting
- Sidebar auto-expands

**Key Metrics**:
- Component functional: YES/NO
- Deep-linking works: YES/NO
- Bugs found: X
- Bugs fixed: Y

---

## Week 2: Page Integration

### Objective
Integrate AskAI buttons into Accounts and Transactions pages with contextual prompts.

### UOWs - Week 2

---

#### UOW-W2-1: Add Account AI Prompts Helper
**Type**: Backend
**Complexity**: M
**Estimated Effort**: 2 hours
**Owner**: Backend Engineer
**Priority**: HIGH

**Description**:
Create helper methods to generate contextual AI prompts for the accounts page based on user's account data.

**Tasks**:
1. Open `/Users/Cody/code_projects/sure/app/helpers/accounts_helper.rb`
2. Add method `account_ai_prompts(account = nil)`:
   - If account provided, return account-specific prompts
   - If nil, return general account prompts
3. Analyze account type (checking, savings, credit, investment, etc.)
4. Consider account balance (positive, negative, zero)
5. Check recent activity (last sync, transaction count)
6. Return array of 3-5 contextual prompt hashes:
   - `{ icon: "...", text: "..." }`
7. Use i18n for all prompt text
8. Handle edge cases (no accounts, new accounts, etc.)

**Acceptance Criteria**:
- [ ] Helper method defined in AccountsHelper
- [ ] Returns array of prompt hashes
- [ ] Prompts vary by account type
- [ ] Considers account balance in suggestions
- [ ] Checks recent activity
- [ ] All prompts use i18n
- [ ] Returns empty array if no accounts
- [ ] Account-specific prompts include account name

**Files to Modify**:
- `/Users/Cody/code_projects/sure/app/helpers/accounts_helper.rb`

**Dependencies**: None

**Example Prompts**:
- Checking account: "Analyze my checking account spending patterns"
- Credit card: "Show me my credit card spending by category"
- Low balance: "Help me understand why my balance is low"
- Multiple accounts: "Compare my account balances and growth"

---

#### UOW-W2-2: Add i18n for Accounts AI Prompts
**Type**: Frontend (i18n)
**Complexity**: S
**Estimated Effort**: 1 hour
**Owner**: Frontend Engineer 1
**Priority**: HIGH

**Description**:
Add all i18n strings for account-related AI prompts.

**Tasks**:
1. Open `/Users/Cody/code_projects/sure/config/locales/en.yml`
2. Add section under `accounts.ai_prompts`:
   ```yaml
   accounts:
     ai_prompts:
       header_prompt: "Analyze my accounts"
       analyze_account: "Analyze %{account_name}"
       compare_accounts: "Compare my account balances"
       spending_patterns: "Show my spending patterns across accounts"
       net_worth: "Calculate my net worth"
       # ... more prompts
   ```
3. Use interpolation for account names: `%{account_name}`
4. Include prompts for different account types
5. Test all keys resolve correctly

**Acceptance Criteria**:
- [ ] i18n keys added under `accounts.ai_prompts`
- [ ] Interpolation syntax correct
- [ ] Keys for all account types
- [ ] Clear, actionable prompt text
- [ ] No duplicate keys
- [ ] Helper uses these keys

**Files to Modify**:
- `/Users/Cody/code_projects/sure/config/locales/en.yml`

**Dependencies**: UOW-W2-1

---

#### UOW-W2-3: Add AskAI Button to Accounts Header
**Type**: Frontend (View)
**Complexity**: S
**Estimated Effort**: 1 hour
**Owner**: Frontend Engineer 1
**Priority**: HIGH

**Description**:
Add prominent AskAI button to accounts page header for general account analysis.

**Tasks**:
1. Open `/Users/Cody/code_projects/sure/app/views/accounts/index.html.erb`
2. Locate header section (around line 1-22)
3. Add AskAI button next to "New account" button:
   ```erb
   <%= render UI::AskAiButton.new(
     prompt: t("accounts.ai_prompts.header_prompt"),
     variant: :button,
     icon: "sparkles"
   ) %>
   ```
4. Ensure proper spacing and alignment
5. Test mobile layout (button may need to hide/shrink)
6. Use existing button group styling

**Acceptance Criteria**:
- [ ] AskAI button renders in header
- [ ] Positioned next to existing actions
- [ ] Uses primary or outline variant
- [ ] Mobile-friendly (responsive)
- [ ] Clicking opens chat with prompt
- [ ] Doesn't break existing layout
- [ ] i18n prompt text used

**Files to Modify**:
- `/Users/Cody/code_projects/sure/app/views/accounts/index.html.erb`

**Dependencies**: UOW-W1-2, UOW-W2-2

**Design Notes**:
- Place before or after "New account" button
- Consider outline variant to not compete with primary action
- On mobile, may show icon-only or move to dropdown

---

#### UOW-W2-4: Create Transactions AI Helper
**Type**: Backend
**Complexity**: L
**Estimated Effort**: 3 hours
**Owner**: Backend Engineer
**Priority**: HIGH

**Description**:
Create comprehensive helper methods for transaction-related AI prompts, considering search filters, selection state, and data quality.

**Tasks**:
1. Create new file: `/Users/Cody/code_projects/sure/app/helpers/transactions_ai_helper.rb`
2. Add method `transaction_list_prompts(search)`:
   - Analyze current search/filters
   - Consider date range
   - Check for uncategorized transactions
   - Detect patterns (recurring, large amounts)
   - Return 3-5 relevant prompts
3. Add method `bulk_transaction_prompts(transaction_ids)`:
   - Accept array of selected transaction IDs
   - Return prompts for bulk operations
   - Examples: categorize, analyze, find similar
4. Add method `uncategorized_prompts(count)`:
   - Return prompts specific to uncategorized count
   - Different messages based on count (1-10, 10-50, 50+)
5. Use i18n for all text
6. Handle edge cases (no transactions, all categorized, etc.)

**Acceptance Criteria**:
- [ ] Helper module created
- [ ] Three methods defined and working
- [ ] Prompts adapt to search context
- [ ] Handles uncategorized count logic
- [ ] Bulk prompts include transaction count
- [ ] All text uses i18n
- [ ] Returns empty array when not applicable
- [ ] No N+1 queries

**Files to Create**:
- `/Users/Cody/code_projects/sure/app/helpers/transactions_ai_helper.rb`

**Dependencies**: None

**Example Prompts**:
- Uncategorized: "Categorize my {count} uncategorized transactions"
- Date range: "Analyze my spending from {start} to {end}"
- Bulk selected: "Help me categorize these {count} transactions"
- Large amounts: "Explain these large transactions"

---

#### UOW-W2-5: Add i18n for Transactions AI
**Type**: Frontend (i18n)
**Complexity**: M
**Estimated Effort**: 1 hour
**Owner**: Frontend Engineer 2
**Priority**: HIGH

**Description**:
Add comprehensive i18n for all transaction AI prompts with pluralization and interpolation.

**Tasks**:
1. Open `/Users/Cody/code_projects/sure/config/locales/en.yml`
2. Add section under `transactions.ai_prompts`:
   ```yaml
   transactions:
     ai_prompts:
       header_prompt: "Analyze my transactions"
       categorize_uncategorized:
         one: "Categorize this uncategorized transaction"
         other: "Categorize %{count} uncategorized transactions"
       analyze_spending: "Analyze my spending patterns"
       find_recurring: "Find my recurring transactions"
       bulk_selected: "Help me with %{count} selected transactions"
       # ... more prompts
   ```
3. Use pluralization for counts
4. Interpolation for dates, amounts, counts
5. Test all keys with helper

**Acceptance Criteria**:
- [ ] i18n keys added under `transactions.ai_prompts`
- [ ] Pluralization rules for counts
- [ ] Interpolation for dynamic values
- [ ] Clear, actionable prompts
- [ ] Helper methods use these keys
- [ ] No missing translation errors

**Files to Modify**:
- `/Users/Cody/code_projects/sure/config/locales/en.yml`

**Dependencies**: UOW-W2-4

---

#### UOW-W2-6: Add AskAI Button to Transactions Header
**Type**: Frontend (View)
**Complexity**: S
**Estimated Effort**: 1 hour
**Owner**: Frontend Engineer 2
**Priority**: HIGH

**Description**:
Add AskAI button to transactions page header for general transaction analysis.

**Tasks**:
1. Open `/Users/Cody/code_projects/sure/app/views/transactions/index.html.erb`
2. Locate header section (around line 2-44)
3. Add AskAI button to action buttons area:
   ```erb
   <%= render UI::AskAiButton.new(
     prompt: transaction_header_ai_prompt(@search),
     variant: :outline,
     icon: "sparkles",
     class: "hidden md:inline-flex"
   ) %>
   ```
4. Create helper method `transaction_header_ai_prompt` if needed
5. Ensure responsive (may hide on mobile)
6. Position logically with other actions

**Acceptance Criteria**:
- [ ] AskAI button in header
- [ ] Responsive layout maintained
- [ ] Prompt contextual to current view
- [ ] Doesn't break existing button layout
- [ ] Mobile layout correct (hidden or icon-only)
- [ ] Clicking opens chat

**Files to Modify**:
- `/Users/Cody/code_projects/sure/app/views/transactions/index.html.erb`
- `/Users/Cody/code_projects/sure/app/helpers/transactions_ai_helper.rb` (add header prompt method)

**Dependencies**: UOW-W1-2, UOW-W2-4, UOW-W2-5

---

#### UOW-W2-7: Add AI Prompt Chips to Transactions Page
**Type**: Frontend (View)
**Complexity**: M
**Estimated Effort**: 2 hours
**Owner**: Frontend Engineer 2
**Priority**: MEDIUM

**Description**:
Add a section below the transactions header showing 3-5 contextual AI prompt chips that users can click.

**Tasks**:
1. Open `/Users/Cody/code_projects/sure/app/views/transactions/index.html.erb`
2. Add new section after summary, before transaction list:
   ```erb
   <div class="flex gap-2 overflow-x-auto pb-2">
     <% transaction_list_prompts(@search).each do |prompt| %>
       <%= render UI::AskAiButton.new(
         prompt: prompt[:text],
         variant: :link,
         icon: prompt[:icon],
         class: "whitespace-nowrap"
       ) %>
     <% end %>
   </div>
   ```
3. Style as horizontal scrollable chips on mobile
4. Limit to 5 prompts
5. Show "sparkles" visual indicator
6. Responsive design (wraps on desktop, scrolls on mobile)

**Acceptance Criteria**:
- [ ] Prompt chips render below header
- [ ] 3-5 prompts shown
- [ ] Horizontal scroll on mobile
- [ ] Wrap or grid on desktop
- [ ] Each chip clickable
- [ ] Visual design matches app style
- [ ] Empty state handled (no prompts = hide section)

**Files to Modify**:
- `/Users/Cody/code_projects/sure/app/views/transactions/index.html.erb`

**Dependencies**: UOW-W2-4, UOW-W2-5, UOW-W1-2

**Design Notes**:
- Use rounded chips with border
- Hover state for feedback
- Small text (text-sm)
- Icon on left

---

#### UOW-W2-8: Add AI to Empty State (Optional - Nice to Have)
**Type**: Frontend (View)
**Complexity**: S
**Estimated Effort**: 1 hour
**Owner**: Frontend Engineer 1
**Priority**: LOW

**Description**:
When no transactions match filters, show AI suggestions for what to do instead of just "No results".

**Tasks**:
1. Open `/Users/Cody/code_projects/sure/app/views/entries/_empty.html.erb`
2. Add AI suggestions section:
   ```erb
   <div class="mt-4">
     <p class="text-sm text-secondary mb-2">Try asking AI:</p>
     <div class="flex flex-col gap-2">
       <%= render UI::AskAiButton.new(
         prompt: "Help me import transactions",
         variant: :link,
         icon: "download"
       ) %>
       <%= render UI::AskAiButton.new(
         prompt: "Set up categories for my transactions",
         variant: :link,
         icon: "shapes"
       ) %>
     </div>
   </div>
   ```
3. Make prompts contextual if possible
4. i18n for prompt text

**Acceptance Criteria**:
- [ ] Empty state shows AI suggestions
- [ ] 2-3 relevant prompts
- [ ] Prompts contextual to empty state reason
- [ ] i18n complete
- [ ] Doesn't clutter empty state
- [ ] Optional/skippable if time constrained

**Files to Modify**:
- `/Users/Cody/code_projects/sure/app/views/entries/_empty.html.erb`

**Dependencies**: UOW-W1-2, UOW-W2-5

---

#### UOW-W2-9: Write Component Tests
**Type**: Testing
**Complexity**: M
**Estimated Effort**: 2 hours
**Owner**: Frontend Engineer 1
**Priority**: MEDIUM

**Description**:
Write comprehensive unit tests for AskAI component covering all variants and edge cases.

**Tasks**:
1. Create file: `/Users/Cody/code_projects/sure/test/components/UI/ask_ai_button_test.rb`
2. Test rendering:
   - Button variant renders DS::Button
   - Link variant renders DS::Link
   - Menu item variant renders correctly
3. Test parameters:
   - Prompt text passed correctly
   - Icon renders
   - Custom classes applied
   - Context serialized
4. Test edge cases:
   - Blank prompt (should raise error)
   - Long prompt (truncates or warns)
   - Special characters in prompt
   - Nil context (defaults to {})
5. Use fixtures for test data

**Acceptance Criteria**:
- [ ] Test file created
- [ ] Tests for all three variants
- [ ] Parameter handling tested
- [ ] Edge cases covered
- [ ] All tests pass
- [ ] Code coverage >80%

**Files to Create**:
- `/Users/Cody/code_projects/sure/test/components/UI/ask_ai_button_test.rb`

**Dependencies**: UOW-W1-2

**Test Structure**:
```ruby
require "test_helper"

class UI::AskAiButtonTest < ViewComponent::TestCase
  test "renders button variant" do
    render_inline(UI::AskAiButton.new(prompt: "Test", variant: :button))
    assert_selector "button", text: "Ask AI"
  end

  test "raises error with blank prompt" do
    assert_raises ArgumentError do
      UI::AskAiButton.new(prompt: "")
    end
  end

  # More tests...
end
```

---

#### UOW-W2-10: Integration Testing & Bug Fixes
**Type**: Testing
**Complexity**: L
**Estimated Effort**: 4 hours
**Owner**: Both Frontend Engineers + Backend Engineer
**Priority**: CRITICAL

**Description**:
End-to-end testing of the complete user journey from accounts/transactions pages to AI chat response.

**Tasks**:
1. Test complete flow on Accounts page:
   - Click header button → chat opens → prompt pre-filled → submit → AI responds
   - Verify context passed correctly
2. Test complete flow on Transactions page:
   - Click header button → works
   - Click prompt chip → works
   - Verify search filters in context
3. Test edge cases:
   - No accounts/transactions
   - Filtered views
   - Mobile vs desktop
4. Cross-browser testing
5. Performance testing (page load time impact)
6. Fix all bugs found
7. Regression testing (ensure nothing broke)
8. Prepare demo

**Acceptance Criteria**:
- [ ] Complete user journey works on Accounts
- [ ] Complete user journey works on Transactions
- [ ] AI receives correct context
- [ ] AI responses relevant to prompts
- [ ] Mobile experience smooth
- [ ] No performance degradation
- [ ] All bugs documented and fixed
- [ ] Ready for sprint demo

**Files to Modify**: Various (bug fixes)

**Dependencies**: All previous UOWs

**Testing Checklist**:
- [ ] Desktop Chrome - Accounts page
- [ ] Desktop Chrome - Transactions page
- [ ] Desktop Safari - Both pages
- [ ] Mobile iOS - Both pages
- [ ] Mobile Android - Both pages
- [ ] Empty states
- [ ] Error states
- [ ] Long prompts
- [ ] Special characters

---

### End of Week 2 / Sprint 1 Demo

**What to Show**:
1. **Accounts Page**:
   - Header AI button
   - Click → sidebar opens → chat with prompt
   - Submit → AI analyzes accounts
2. **Transactions Page**:
   - Header AI button
   - Contextual prompt chips
   - Different prompts based on search
   - Click chip → chat opens
   - Bulk selection AI prompts (if completed)
3. **Mobile Experience**:
   - Show same flow on mobile device
   - Full page navigation
4. **Component Demo**:
   - Show Lookbook with all variants

**Success Metrics to Report**:
- Components delivered: X/X
- UOWs completed: X/X
- Bugs found: X
- Bugs fixed: Y
- Test coverage: Z%
- Pages with AI: 2 (Accounts, Transactions)
- Ready for production: YES/NO

**Risks to Escalate**:
- Any incomplete critical UOWs
- Performance issues discovered
- Cross-browser bugs
- Scope creep requests

---

## Sprint 1 Summary

### Total UOWs: 19
- Week 1: 9 UOWs
- Week 2: 10 UOWs

### Complexity Breakdown:
- Small (S): 7 UOWs = 7-10 hours
- Medium (M): 10 UOWs = 20-30 hours
- Large (L): 2 UOWs = 6-8 hours
- **Total Estimated Effort**: ~35-50 hours

### By Type:
- Frontend (Component): 3 UOWs
- Frontend (View): 5 UOWs
- Frontend (JavaScript): 2 UOWs
- Frontend (i18n): 3 UOWs
- Backend: 3 UOWs
- Testing: 2 UOWs
- Documentation: 1 UOW

### Critical Path:
```
W1-1 → W1-2 → W1-3 → W1-4 → W1-5
              ↓
W1-6 → W1-7 → W1-8
       ↓
W2-1 → W2-2 → W2-3
       ↓
W2-4 → W2-5 → W2-6 → W2-7
```

### Team Allocation:
- **Frontend Engineer 1**: UOWs W1-1, W1-2, W1-3, W1-4, W1-5, W2-2, W2-3, W2-8, W2-9
- **Frontend Engineer 2**: UOWs W1-7, W1-8, W2-5, W2-6, W2-7
- **Backend Engineer**: UOWs W1-6, W2-1, W2-4
- **Both Frontend**: UOWs W1-9 (testing)
- **All Engineers**: UOW W2-10 (integration testing)

### Definition of Done (Sprint 1):
- [ ] All CRITICAL and HIGH priority UOWs completed
- [ ] AskAI component functional and tested
- [ ] Deep-linking works desktop + mobile
- [ ] Accounts page has AI button
- [ ] Transactions page has AI button + chips
- [ ] All new code has i18n
- [ ] Component tests written and passing
- [ ] Integration tests completed
- [ ] No P1 bugs
- [ ] Demo successful
- [ ] Code reviewed and merged
- [ ] Documentation updated

### Success Criteria:
- **Functional**: Users can click AI buttons on 2 pages and get AI help
- **Quality**: Zero P1 bugs, tests passing, i18n complete
- **UX**: Smooth experience desktop + mobile
- **Performance**: No noticeable page load degradation
- **Ready**: Deployable to production

---

## Appendix: Technical Reference

### File Structure Created/Modified

**New Files**:
- `/Users/Cody/code_projects/sure/app/components/UI/ask_ai_button.rb`
- `/Users/Cody/code_projects/sure/app/components/UI/ask_ai_button.html.erb`
- `/Users/Cody/code_projects/sure/app/javascript/controllers/ask_ai_controller.js`
- `/Users/Cody/code_projects/sure/test/components/previews/ask_ai_button_preview.rb`
- `/Users/Cody/code_projects/sure/app/helpers/transactions_ai_helper.rb`
- `/Users/Cody/code_projects/sure/test/components/UI/ask_ai_button_test.rb`

**Modified Files**:
- `/Users/Cody/code_projects/sure/app/controllers/chats_controller.rb`
- `/Users/Cody/code_projects/sure/app/views/chats/new.html.erb`
- `/Users/Cody/code_projects/sure/app/javascript/controllers/app_layout_controller.js`
- `/Users/Cody/code_projects/sure/app/helpers/accounts_helper.rb`
- `/Users/Cody/code_projects/sure/config/locales/en.yml`
- `/Users/Cody/code_projects/sure/app/views/accounts/index.html.erb`
- `/Users/Cody/code_projects/sure/app/views/transactions/index.html.erb`
- `/Users/Cody/code_projects/sure/app/views/entries/_empty.html.erb`

### Key Dependencies
- Hotwire (Turbo + Stimulus)
- ViewComponent
- Design System components (DS::Button, DS::Link)
- i18n (Rails internationalization)
- Existing chat infrastructure

### Development Commands

**Start development server**:
```bash
bin/dev
```

**Run tests**:
```bash
bin/rails test test/components/UI/ask_ai_button_test.rb
```

**View Lookbook**:
```bash
# Navigate to http://localhost:3000/lookbook
```

**Check i18n keys**:
```bash
bin/rails i18n:missing_keys
```

**Lint code**:
```bash
bin/rubocop -f github -a
bundle exec erb_lint ./app/**/*.erb -a
```

### Debug Tips

**Component not rendering**:
- Check Lookbook preview first
- Verify all parameters passed correctly
- Check browser console for Stimulus errors

**Deep-link not working**:
- Check URL encoding (use `encodeURIComponent`)
- Verify ChatsController receives params
- Check Turbo frame targets

**Sidebar not expanding**:
- Verify `app-layout` controller loaded
- Check viewport width detection
- Look for JavaScript errors in console

**Prompts not contextual**:
- Verify helper methods called correctly
- Check data availability (accounts, transactions)
- Review i18n interpolation

---

## Next Steps After Sprint 1

**Sprint 2 Preview** (not included in this document):
- Build comprehensive prompt context system
- Add AI to Reports and Budgets pages
- Implement page-aware chat sidebar
- Create "Examples for this page" section
- Expand prompt library

**Retrospective Topics**:
- Did UOW estimates match actuals?
- Were dependencies clear enough?
- Any scope creep?
- What blockers occurred?
- How to improve Sprint 2?

**Metrics to Gather**:
- AI button click rate (week 1 after launch)
- Prompt usage distribution
- Mobile vs desktop usage
- Most clicked prompts
- Completion rate (click → AI response)
