# PRP: Send Complete Journal Entry in Email Notification

**Status:** Draft
**Date:** 2026-04-01
**Type:** Enhancement
**Confidence Score:** 8/10 (well-scoped, clear patterns to follow, but HTML email styling and ActionText-in-email edge cases add moderate risk)

---

## Problem Statement

The `entry_created` notification email currently sends a minimal summary:

```
<author> added a new entry "<entry_name>" to the trip "<trip_name>".

View the entry: https://catalyst.workeverywhere.docker/trips/:trip_id/journal-entries/:entry_id
```

**Desired behavior:** The email should include the **complete journal entry content** (title, date, location, description, and full ActionText body) so recipients can read the entry directly from their inbox. The link should be changed from `View the entry: <URL>` to a `[Read Online]` hyperlink.

---

## Codebase Context

### Key Files

| File | Role | Lines |
|------|------|-------|
| `app/mailers/notification_mailer.rb` | **MODIFY** - Mailer class, eager-load rich text | 32 lines |
| `app/views/notification_mailer/entry_created.text.erb` | **MODIFY** - Text email template | 3 lines |
| `app/views/notification_mailer/entry_created.html.erb` | **CREATE** - HTML email template with full content | New file |
| `app/views/layouts/mailer.html.erb` | **MODIFY** - HTML email layout with proper styling | 13 lines |
| `app/views/layouts/mailer.text.erb` | No change - just `<%= yield %>` | 1 line |
| `app/models/journal_entry.rb` | Reference - `has_rich_text :body` | 21 lines |
| `app/views/journal_entries/show.rb` | Reference - how body is rendered on web | 183 lines |
| `app/jobs/notify_entry_created_job.rb` | Reference - how the mailer is called | 23 lines |
| `spec/jobs/notify_entry_created_job_spec.rb` | Reference - existing test patterns | 34 lines |
| `app/mailers/application_mailer.rb` | Reference - base class, `layout "mailer"` | 6 lines |

### Current Email Flow

```
JournalEntries::Create action
  -> emits "journal_entry.created" event
  -> NotificationSubscriber picks it up
  -> NotifyEntryCreatedJob enqueues for each trip member (except author)
  -> NotificationMailer.entry_created(entry.id, member.id).deliver_later
```

### JournalEntry Content Fields

- `name` (string) - Entry title (required)
- `entry_date` (date) - When the entry occurred (required)
- `description` (text) - Short description (optional, plain text)
- `location_name` (string) - Location (optional)
- `body` (ActionText rich text) - Full content with HTML formatting + embedded attachments
- `author` (User association) - `name` and `email` fields

### ActionText Rendering

- `@entry.body.to_s` returns sanitized HTML (safe for rendering in views)
- `@entry.body.to_plain_text` returns stripped plain text (for text emails)
- `@entry.body.present?` checks if body has content
- ActionText HTML may contain `<action-text-attachment>` tags for embedded images; these reference signed blob URLs that require authentication and expire. They will NOT render in email clients.

### Current Mailer Class

```ruby
class NotificationMailer < ApplicationMailer
  def entry_created(journal_entry_id, recipient_id)
    @entry = JournalEntry.find_by(id: journal_entry_id)
    @recipient = User.find_by(id: recipient_id)
    return unless @entry && @recipient

    @trip = @entry.trip
    @author = @entry.author

    mail(
      to: @recipient.email,
      subject: "New entry in #{@trip.name}: #{@entry.name}"
    )
  end
end
```

### All Existing Emails Are Text-Only

Every mailer in the project uses `.text.erb` templates only. No HTML email templates exist. The HTML layout (`app/views/layouts/mailer.html.erb`) is minimal:

```html
<!DOCTYPE html>
<html>
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    <style>/* Email styles need to be inline */</style>
  </head>
  <body>
    <%= yield %>
  </body>
</html>
```

### Design System Variables (for reference, NOT usable in emails)

The web app uses CSS custom properties (`--ha-primary`, `--ha-card`, etc.) from `app/assets/tailwind/application.css`. These are NOT available in emails. Email styling must use hardcoded inline CSS values.

---

## Implementation Plan

### Approach

1. Create an HTML email template with inline CSS that presents the full journal entry
2. Update the text email template to include the plain-text body content
3. Change the link text from "View the entry: <URL>" to "[Read Online]" in both templates
4. Eager-load `rich_text_body` in the mailer to avoid N+1
5. Strip `<action-text-attachment>` tags from the HTML body before including in email (embedded images use signed URLs that won't work in email clients)
6. Add mailer unit specs
7. Update the factory to include a `:with_body` trait for testing

### Important: HTML Email Constraints

- **No CSS variables** - hardcode all color values
- **No external stylesheets** - all CSS must be inline on elements
- **No Tailwind** - email clients strip `<style>` blocks; use inline styles
- **Table-based layout** - for maximum email client compatibility
- **Safe HTML only** - ActionText `to_s` is already sanitized by Rails, but `<action-text-attachment>` tags must be stripped
- **Multi-part email** - When Rails finds both `.html.erb` and `.text.erb` templates, it automatically sends a `multipart/alternative` email. No mailer code changes needed for this.

### ActionText Attachment Handling

ActionText content may contain `<action-text-attachment>` HTML elements that reference Active Storage blobs via signed GlobalIDs. These blobs:
- Require authentication to access
- Have expiring signed URLs
- Won't render in email clients

**Strategy:** Strip `<action-text-attachment>` elements from the HTML before rendering in email. Replace them with a placeholder like "[Image]" or simply remove them. Use `Nokogiri` (already a Rails dependency) to process the HTML.

Add a private helper method to the mailer:

```ruby
def sanitize_body_for_email(rich_text)
  return "" unless rich_text.present?

  html = rich_text.to_s
  doc = Nokogiri::HTML.fragment(html)
  doc.css("action-text-attachment").each(&:remove)
  doc.to_html
end
```

### Pseudocode

#### 1. Updated Mailer (`app/mailers/notification_mailer.rb`)

```ruby
class NotificationMailer < ApplicationMailer
  def entry_created(journal_entry_id, recipient_id)
    @entry = JournalEntry.includes(:rich_text_body)
                         .find_by(id: journal_entry_id)
    @recipient = User.find_by(id: recipient_id)
    return unless @entry && @recipient

    @trip = @entry.trip
    @author = @entry.author
    @entry_url = trip_journal_entry_url(@trip, @entry)
    @email_body_html = sanitize_body_for_email(@entry.body)

    mail(
      to: @recipient.email,
      subject: "New entry in #{@trip.name}: #{@entry.name}"
    )
  end

  private

  def sanitize_body_for_email(rich_text)
    return "" unless rich_text.present?

    html = rich_text.to_s
    doc = Nokogiri::HTML.fragment(html)
    doc.css("action-text-attachment").each(&:remove)
    doc.to_html
  end
end
```

#### 2. Text Template (`app/views/notification_mailer/entry_created.text.erb`)

```erb
<%= @author.name || @author.email %> added a new entry to the trip "<%= @trip.name %>".

---

<%= @entry.name %>
<%= @entry.entry_date.to_fs(:long) %>
<% if @entry.location_name.present? %><%= @entry.location_name %><% end %>

<% if @entry.description.present? %><%= @entry.description %>

<% end %><% if @entry.body.present? %><%= @entry.body.to_plain_text %>

<% end %>---

Read Online: <%= @entry_url %>
```

#### 3. HTML Template (`app/views/notification_mailer/entry_created.html.erb`)

Build a clean, email-safe HTML template using inline styles and table layout. Include:
- Header section with trip name, entry title, date, and location
- Description block (if present)
- Full body content (sanitized HTML from ActionText)
- Footer with [Read Online] button/link

Use hardcoded colors derived from the design system:
- Background: `#faf8ff` (from `--ha-bg`)
- Card: `#ffffff` (from `--ha-card`)
- Text: `#131b2e` (from `--ha-text`)
- Muted: `#3e484f` (from `--ha-muted`)
- Primary: `#00668a` (from `--ha-primary`)
- Primary on: `#ffffff` (from `--ha-on-primary`)

#### 4. HTML Layout (`app/views/layouts/mailer.html.erb`)

Update the shared HTML layout to provide a proper email wrapper. Since all other mailers are text-only, they won't be affected by the HTML layout changes (Rails only renders the HTML layout when an HTML template exists).

```html
<!DOCTYPE html>
<html>
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
  </head>
  <body style="margin: 0; padding: 0; background-color: #faf8ff;
               font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI',
               Roboto, Helvetica, Arial, sans-serif;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
           style="background-color: #faf8ff;">
      <tr>
        <td align="center" style="padding: 24px 16px;">
          <table role="presentation" width="600" cellpadding="0"
                 cellspacing="0"
                 style="max-width: 600px; width: 100%;">
            <tr>
              <td>
                <%= yield %>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>
```

---

## Tasks (in order)

1. **Update the journal_entry factory** (`spec/factories/journal_entries.rb`)
   - Add a `:with_body` trait that sets `body { "Sample journal entry content with <strong>bold text</strong>." }`
   - This enables mailer tests to verify body rendering

2. **Update the mailer class** (`app/mailers/notification_mailer.rb`)
   - Add `includes(:rich_text_body)` to the `JournalEntry.find_by` call
   - Set `@entry_url` instance variable for use in templates
   - Set `@email_body_html` with sanitized body HTML (strip `<action-text-attachment>` tags)
   - Add private `sanitize_body_for_email` method
   - Keep `comment_added` method unchanged

3. **Update the text email template** (`app/views/notification_mailer/entry_created.text.erb`)
   - Include entry metadata (name, date, location)
   - Include description (if present)
   - Include plain text body via `@entry.body.to_plain_text` (if present)
   - Change link from `View the entry: <URL>` to `Read Online: <URL>`

4. **Create the HTML email template** (`app/views/notification_mailer/entry_created.html.erb`)
   - Table-based layout with inline CSS
   - Header: trip name overline, entry title, date, optional location
   - Content: description paragraph (if present), then full sanitized body HTML
   - Footer: `[Read Online]` styled as a button-link
   - Use hardcoded color values from the design system

5. **Update the HTML email layout** (`app/views/layouts/mailer.html.erb`)
   - Add viewport meta tag
   - Add centered table wrapper with max-width 600px
   - Set background color and system font stack
   - Ensure it wraps content cleanly for the new HTML template

6. **Add mailer specs** (`spec/mailers/notification_mailer_spec.rb`)
   - Test `entry_created` email:
     - Sets correct subject
     - Sends to correct recipient
     - HTML part contains the entry name, date, body content
     - HTML part contains "Read Online" link
     - Text part contains plain text body
     - Text part contains "Read Online" link
     - Handles entries with no body gracefully
     - Handles entries with no description gracefully
     - Strips `<action-text-attachment>` from HTML body
   - Test `comment_added` email still works (regression check)

7. **Run linting and tests**
   - `bundle exec rake project:fix-lint`
   - `bundle exec rake project:lint`
   - `bundle exec rake project:tests`
   - `bundle exec rake project:system-tests`

8. **Live verification**
   - `bin/cli app rebuild && bin/cli app restart`
   - `bin/cli mail start`
   - Create a journal entry with rich text body content
   - Verify email in MailCatcher at `https://mail.workeverywhere.docker/`:
     - HTML version renders with full entry content
     - Text version contains plain text body
     - [Read Online] link works and navigates to the entry
     - Layout looks correct (centered, readable, no broken images)
     - Test with entry that has no body (just name/date)
     - Test with entry that has embedded images (verify they're stripped cleanly)

---

## Validation Gates

### Automated Tests

```bash
# Run all tests (chains activation command - see ruby-version-manager skill)
bundle exec rake project:tests
bundle exec rake project:system-tests
```

### Mailer Spec Pattern

```ruby
# spec/mailers/notification_mailer_spec.rb
require "rails_helper"

RSpec.describe NotificationMailer do
  let(:admin) { create(:user, :superadmin, name: "Alice") }
  let(:trip) { create(:trip, name: "Japan Trip", created_by: admin) }
  let(:member) { create(:user, name: "Bob") }
  let(:entry) do
    create(:journal_entry, :with_body, :with_location,
           trip: trip, author: admin, name: "Day in Tokyo")
  end

  before do
    create(:trip_membership, trip: trip, user: member)
    create(:trip_membership, trip: trip, user: admin)
  end

  describe "#entry_created" do
    let(:mail) { described_class.entry_created(entry.id, member.id) }

    it "sends to the recipient" do
      expect(mail.to).to eq([member.email])
    end

    it "sets the subject with trip and entry names" do
      expect(mail.subject).to eq(
        "New entry in Japan Trip: Day in Tokyo"
      )
    end

    it "includes entry content in HTML part" do
      html = mail.html_part.body.to_s
      expect(html).to include("Day in Tokyo")
      expect(html).to include("Read Online")
    end

    it "includes entry content in text part" do
      text = mail.text_part.body.to_s
      expect(text).to include("Day in Tokyo")
      expect(text).to include("Read Online")
    end

    it "returns nil when entry not found" do
      result = described_class.entry_created("nonexistent", member.id)
      expect(result.message).to be_a(ActionMailer::Base::NullMail)
    end
  end
end
```

### Linting

```bash
bundle exec rake project:fix-lint
bundle exec rake project:lint
```

### Live Runtime Verification

```bash
bin/cli app rebuild
bin/cli app restart
bin/cli mail start
```

Then verify with `agent-browser`:
- [ ] Create a journal entry with rich text body
- [ ] Check MailCatcher for the notification email
- [ ] HTML version shows full entry content (title, date, location, body)
- [ ] HTML version has [Read Online] button linking to the entry
- [ ] Text version shows plain text body content
- [ ] Text version has "Read Online: <URL>" link
- [ ] Email renders correctly (centered card layout, readable typography)
- [ ] Entry with no body renders cleanly (no empty blocks)
- [ ] Entry with embedded images strips attachments cleanly

---

## Gotchas & Edge Cases

1. **ActionText `<action-text-attachment>` tags**: These reference Active Storage blobs via signed URLs that expire and require authentication. They will show broken images in email. Must be stripped before rendering. Use `Nokogiri::HTML.fragment(html).css("action-text-attachment").each(&:remove)`. Nokogiri is already a Rails dependency.

2. **Multi-part email auto-detection**: Rails automatically sends `multipart/alternative` when both `.html.erb` and `.text.erb` templates exist for the same mailer action. No code changes needed in the mailer for this -- just create both template files.

3. **Shared HTML layout affects all mailers**: The layout `mailer.html.erb` is shared. However, since no other mailer has an `.html.erb` template, they will continue to send text-only. Rails only renders the HTML layout when an HTML template exists for the action.

4. **`rich_text_body` eager loading**: Without `includes(:rich_text_body)`, accessing `@entry.body` triggers a separate query inside the background job. Add eager loading to avoid this.

5. **Email client CSS support**: Email clients (Gmail, Outlook, Apple Mail) have wildly different CSS support. Stick to:
   - Inline styles only (no `<style>` blocks, no classes)
   - Table-based layout
   - System font stack
   - No CSS custom properties, no flexbox, no grid
   - Reference: https://www.caniemail.com/

6. **Empty body / missing optional fields**: The entry `body` and `description` are optional. Templates must conditionally render these sections. Test with entries that have:
   - Only name + date (minimum required fields)
   - Name + date + description (no body)
   - Name + date + body (no description)
   - All fields populated

7. **HTML sanitization**: ActionText `to_s` already sanitizes HTML (strips scripts, etc.). The email body HTML is safe to render. Only `<action-text-attachment>` tags need additional processing.

8. **`to_plain_text` for text emails**: `@entry.body.to_plain_text` strips all HTML and returns readable plain text. This is the correct method for the text template -- do NOT use `to_s` (which returns HTML).

9. **Tailwind JIT**: This change does not add any Tailwind classes to web views, so no Docker rebuild is needed for the CSS pipeline. Email templates use inline styles only.

10. **`comment_added` email**: The user request specifically targets the `entry_created` email. Do NOT modify `comment_added.text.erb` in this PR. It can be enhanced separately if desired.

---

## Files Changed Summary

| File | Change Type | Description |
|------|-------------|-------------|
| `app/mailers/notification_mailer.rb` | Modified | Eager-load rich text, add sanitize helper, set template vars |
| `app/views/notification_mailer/entry_created.text.erb` | Modified | Include full plain text body + [Read Online] link |
| `app/views/notification_mailer/entry_created.html.erb` | Created | HTML email with full entry content |
| `app/views/layouts/mailer.html.erb` | Modified | Proper email-safe HTML wrapper layout |
| `spec/mailers/notification_mailer_spec.rb` | Created | Mailer unit tests |
| `spec/factories/journal_entries.rb` | Modified | Add `:with_body` trait |

---

## Workflow

Follow the `/execution-plan` skill:
1. Create GitHub issue for this enhancement
2. Move to Kanban board
3. Create feature branch
4. Implement changes (tasks 1-6 above)
5. Run tests + linting (task 7)
6. Live verification with agent-browser (task 8)
7. Push branch and create PR

---

## Quality Checklist

- [x] All necessary context included (mailer code, templates, model fields, ActionText behavior)
- [x] Validation gates are executable by AI (test commands, spec patterns, lint commands)
- [x] References existing patterns (factory traits, mailer structure, show view rendering)
- [x] Clear implementation path (6 ordered tasks with pseudocode)
- [x] Error handling documented (10 gotchas covering email rendering, ActionText, edge cases)
- [x] Scope is clear (entry_created only, not comment_added)
