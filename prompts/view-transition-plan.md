Plan: Migrate ERB Views to Phlex Views

```
~/.claude/plans/dynamic-bouncing-sparrow.md
```

```
claude --dangerously-skip-permissions --resume "migrate-erb-to-phlex"
```

Context

The Catalyst app (Rails 8.1.2, Ruby 4.0.1) uses 32 ERB view files across layout, welcome, users, accounts, shared, and rodauth directories. The goal is to migrate all views (except mailers and PWA
manifest) to Phlex components for type-safe, object-oriented, composable views in pure Ruby. This includes converting the 240-line application layout.

---
Phase 0: Setup

0.1 Add gems to Gemfile

gem "phlex-rails", "~> 2.0"

# In test group:
gem "phlex-testing-capybara"
Run bundle install.

0.2 Update Tailwind config

File: config/tailwind.config.js — Add .rb to view content paths:
content: [
  "./app/views/**/*.{erb,html,rb}",  // added .rb
  "./app/helpers/**/*.rb",
  "./app/javascript/**/*.js",
  "./app/components/**/*.{erb,rb}"
]

0.3 Create base classes

app/components/base.rb — Base for all reusable components:
class Components::Base < Phlex::HTML
  include Phlex::Rails::Helpers::Routes

  if Rails.env.development?
    def before_template
      comment { "Begin #{self.class.name}" }
      super
    end
  end
end

app/views/base.rb — Base for page-level views:
class Views::Base < Components::Base
  include Phlex::Rails::Helpers::ContentFor
end

---
Phase 1: Extract Reusable Components

1.1 SVG Icons — app/components/icons/

Create Phlex::SVG subclasses for each inline SVG (~15 icons: home, users, plus, check, alert, close, chevron_left, sun, moon, sign_in, sign_out, person, key, key_remove, create_account). Each takes
optional css: param.

1.2 Shared UI Components — app/components/

- page_header.rb — Section label + title + subtitle + action buttons block
- notice_banner.rb — Emerald notice card (used in users/index, users/show, accounts/show)
- flash_toasts.rb — Fixed-position toast notifications (notice/alert) with Stimulus toast controller data attributes
- nav_item.rb — Sidebar navigation link item
- sidebar.rb — Full sidebar navigation (uses NavItem, Icons, auth/authorization checks via view_context)

---
Phase 2: Convert Partials to Components

2.1 User partials

- users/_user.html.erb → app/components/user_card.rb — User card with conditional View/Edit links
- users/_form.html.erb → app/components/user_form.rb — Form with name, email, roles checkboxes (form_with, collection_check_boxes)

2.2 Account partials

- accounts/_details.html.erb → app/components/account_details.rb
- accounts/_form.html.erb → app/components/account_form.rb (uses url: account_path)

2.3 Shared views

- shared/unauthorized.html.erb → app/views/shared/unauthorized.rb

2.4 Rodauth partials

- rodauth/_flash.html.erb → app/components/rodauth_flash.rb
- rodauth/_login_form.html.erb → app/components/rodauth_login_form.rb
- rodauth/_login_form_footer.html.erb → app/components/rodauth_login_form_footer.rb
- rodauth/_email_auth_request_form.html.erb → app/components/rodauth_email_auth_request_form.rb

Delete original ERB files after each conversion, run tests.

---
Phase 3: Convert Page Views

3.1 Users views

- users/index.html.erb → app/views/users/index.rb — Renders PageHeader + NoticeBanner + UserCard collection
- users/show.html.erb → app/views/users/show.rb — Renders PageHeader + NoticeBanner + UserCard
- users/new.html.erb → app/views/users/new.rb — Renders PageHeader + UserForm in card
- users/edit.html.erb → app/views/users/edit.rb — Renders PageHeader + UserForm in card

Update UsersController to render Phlex views explicitly:
def index
  @users = User.all
  render Views::Users::Index.new(users: @users)
end

3.2 Accounts views

- accounts/show.html.erb → app/views/accounts/show.rb
- accounts/edit.html.erb → app/views/accounts/edit.rb

Update AccountsController similarly.

3.3 Welcome view

- welcome/home.html.erb → app/views/welcome/home.rb

Update WelcomeController.

Delete original ERB files after each batch.

---
Phase 4: Convert Rodauth Views

Strategy: Thin ERB wrappers — Rodauth internally calls render expecting template names. Each Rodauth ERB becomes a one-liner delegating to a Phlex component:

<%# app/views/rodauth/login.html.erb %>
<%= render Views::Rodauth::Login.new %>

The Phlex class does all the work in app/views/rodauth/login.rb.

Views to convert (10 full pages + 4 partials already done in Phase 2):
- login, create_account, logout, email_auth, verify_account, verify_account_resend, multi_phase_login, webauthn_auth, webauthn_setup, webauthn_remove

Key patterns for Rodauth Phlex views:
- Use view_context.rodauth to access Rodauth instance
- Use raw safe(view_context.rodauth.login_additional_form_tags) for form tags (CSRF, hidden fields)
- Use raw safe(view_context.rodauth.render_multi_phase_login_forms) for multi-phase login
- WebAuthn views need javascript_include_tag (include Phlex::Rails::Helpers::JavaScriptIncludeTag)
- All auth forms use data: { turbo: false }

---
Phase 5: Convert Application Layout

5.1 Create Phlex layout

app/views/layouts/application_layout.rb
class Views::Layouts::ApplicationLayout < Phlex::HTML
  include Phlex::Rails::Layout
  include Phlex::Rails::Helpers::CSRFMetaTags
  include Phlex::Rails::Helpers::CSPMetaTag
  include Phlex::Rails::Helpers::StyleSheetLinkTag
  include Phlex::Rails::Helpers::JavaScriptImportmapTags
  include Phlex::Rails::Helpers::ContentFor
  include Phlex::Rails::Helpers::Flash
end

Decomposed into private methods: render_head, render_main, render_background_decorations. Delegates sidebar to Components::Sidebar, flash messages to Components::FlashToasts.

5.2 Wire up in controller

class ApplicationController < ActionController::Base
  layout -> { Views::Layouts::ApplicationLayout }
end

5.3 Delete app/views/layouts/application.html.erb

Keep as ERB: mailer.html.erb, mailer.text.erb (mailer layouts stay ERB).

---
Phase 6: Update Tests

6.1 View specs → Component specs

Move/rewrite specs from spec/views/users/ to spec/components/ and spec/views/.

Use render_inline from phlex-testing-capybara:
RSpec.describe Views::Users::Index do
  it "renders a list of users" do
    result = render_inline(described_class.new(users: users))
    expect(result).to have_css("p", text: "Name", count: 2)
  end
end

6.2 System tests — no changes expected

System tests work at browser level and should pass without modification.

6.3 Delete old view spec files

Remove *.html.tailwindcss_spec.rb files after replacement specs pass.

---
Phase 7: Cleanup

- Scope ErbLint to remaining ERB files (mailers, PWA, rodauth thin wrappers)
- Verify RuboCop passes on all new .rb files
- Remove any unused helpers

---
Files Modified/Created Summary

┌─────────┬───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Action  │                                                                               Path                                                                                │
├─────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Edit    │ Gemfile — add phlex-rails, phlex-testing-capybara                                                                                                                 │
├─────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Edit    │ config/tailwind.config.js — add .rb to content paths                                                                                                              │
├─────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Edit    │ app/controllers/application_controller.rb — layout directive                                                                                                      │
├─────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Edit    │ app/controllers/users_controller.rb — explicit Phlex renders                                                                                                      │
├─────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Edit    │ app/controllers/accounts_controller.rb — explicit Phlex renders                                                                                                   │
├─────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Edit    │ app/controllers/welcome_controller.rb — explicit Phlex render                                                                                                     │
├─────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Create  │ app/components/base.rb                                                                                                                                            │
├─────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Create  │ app/views/base.rb                                                                                                                                                 │
├─────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Create  │ app/views/layouts/application_layout.rb                                                                                                                           │
├─────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Create  │ app/components/sidebar.rb                                                                                                                                         │
├─────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Create  │ app/components/flash_toasts.rb                                                                                                                                    │
├─────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Create  │ app/components/page_header.rb                                                                                                                                     │
├─────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Create  │ app/components/notice_banner.rb                                                                                                                                   │
├─────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Create  │ app/components/nav_item.rb                                                                                                                                        │
├─────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Create  │ app/components/icons/*.rb (~15 files)                                                                                                                             │
├─────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Create  │ app/components/user_card.rb                                                                                                                                       │
├─────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Create  │ app/components/user_form.rb                                                                                                                                       │
├─────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Create  │ app/components/account_details.rb                                                                                                                                 │
├─────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Create  │ app/components/account_form.rb                                                                                                                                    │
├─────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Create  │ app/components/rodauth_flash.rb                                                                                                                                   │
├─────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Create  │ app/components/rodauth_login_form.rb                                                                                                                              │
├─────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Create  │ app/components/rodauth_login_form_footer.rb                                                                                                                       │
├─────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Create  │ app/components/rodauth_email_auth_request_form.rb                                                                                                                 │
├─────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Create  │ app/views/welcome/home.rb                                                                                                                                         │
├─────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Create  │ app/views/users/{index,show,new,edit}.rb                                                                                                                          │
├─────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Create  │ app/views/accounts/{show,edit}.rb                                                                                                                                 │
├─────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Create  │ app/views/shared/unauthorized.rb                                                                                                                                  │
├─────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Create  │ app/views/rodauth/{login,create_account,logout,email_auth,verify_account,verify_account_resend,multi_phase_login,webauthn_auth,webauthn_setup,webauthn_remove}.rb │
├─────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Rewrite │ app/views/rodauth/*.html.erb — thin wrappers (14 files)                                                                                                           │
├─────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Delete  │ app/views/layouts/application.html.erb                                                                                                                            │
├─────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Delete  │ app/views/welcome/home.html.erb                                                                                                                                   │
├─────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Delete  │ app/views/users/*.html.erb (6 files)                                                                                                                              │
├─────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Delete  │ app/views/accounts/*.html.erb (4 files)                                                                                                                           │
├─────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Delete  │ app/views/shared/unauthorized.html.erb                                                                                                                            │
├─────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Rewrite │ spec/views/users/*_spec.rb (4 files)                                                                                                                              │
├─────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Delete  │ spec/views/welcome/home.html.tailwindcss_spec.rb                                                                                                                  │
└─────────┴───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

Kept as ERB: layouts/mailer.{html,text}.erb, rodauth_mailer/*.erb, pwa/manifest.json.erb

---
Verification

After each phase, run:
1. bundle exec rake project:fix-lint && bundle exec rake project:lint
2. bundle exec rake project:tests
3. bundle exec rake project:system-tests
4. Visual check at https://catalyst.workeverywhere.docker — verify layout, sidebar nav, flash toasts, theme toggle, auth flows, user CRUD, account pages

---
Workflow (per AGENTS.md)

1. Create GitHub issue with this plan
2. Move to Backlog → Ready → In Progress on Kanban
3. Create feature branch: feature/migrate-erb-to-phlex
4. Implement phases 0-7
5. Run all pre-commit validation (lint + tests + system tests)
6. Push branch, create PR, move issue to In Review
