# PRP: Comment Notification Email — Full Content Pattern

**Status:** Draft
**Date:** 2026-04-01
**Type:** Enhancement
**Confidence Score:** 9/10 (direct pattern copy from entry_created; all templates, helpers, and test patterns already exist)

---

## Problem Statement

The `comment_added` notification email currently sends a minimal 3-line text-only message:

```
<commenter> commented on "<entry_name>" in the trip "<trip_name>".

View the entry: <URL>
```

It has **no HTML template**, **no comment body**, **no entry context** (date, location), and **no "Read Online" button**. The `entry_created` email was already upgraded to include full content with an HTML template, inline images, and a styled "Read Online" link.

**Desired behavior:** The `comment_added` email must follow the exact same pattern as `entry_created` — include the comment body, entry context (title, date, location), commenter info, and a "Read Online" button in both HTML and text formats.

---

## Pattern to Follow: `entry_created` Email

The `entry_created` email is the reference implementation. The `comment_added` email must mirror its structure with comment-specific content.

### Current `entry_created` Mailer Method

```ruby
# app/mailers/notification_mailer.rb (lines 4-19)
def entry_created(journal_entry_id, recipient_id)
  @entry = JournalEntry.find_by(id: journal_entry_id)
  @recipient = User.find_by(id: recipient_id)
  return unless @entry && @recipient

  @trip = @entry.trip
  @author = @entry.author
  @entry_url = trip_journal_entry_url(@trip, @entry)
  @email_body_html = sanitize_body_for_email(@entry.body).html_safe
  attach_inline_images

  mail(
    to: @recipient.email,
    subject: "New entry in #{@trip.name}: #{@entry.name}"
  )
end
```

### Current `comment_added` Mailer Method (to be updated)

```ruby
# app/mailers/notification_mailer.rb (lines 21-34)
def comment_added(comment_id, recipient_id)
  @comment = Comment.find_by(id: comment_id)
  @recipient = User.find_by(id: recipient_id)
  return unless @comment && @recipient

  @entry = @comment.journal_entry
  @trip = @entry.trip
  @commenter = @comment.user

  mail(
    to: @recipient.email,
    subject: "New comment on #{@entry.name} in #{@trip.name}"
  )
end
```

**What's missing:** `@entry_url`, no HTML template, no comment body rendering.

---

## Codebase Context

### Key Files

| File | Role |
|------|------|
| `app/mailers/notification_mailer.rb` | **MODIFY** — add `@entry_url` to `comment_added` |
| `app/views/notification_mailer/comment_added.text.erb` | **MODIFY** — expand to include comment body + entry context |
| `app/views/notification_mailer/comment_added.html.erb` | **CREATE** — HTML email mirroring entry_created structure |
| `spec/mailers/notification_mailer_spec.rb` | **MODIFY** — expand `#comment_added` tests |

### Reference Files (do not modify)

| File | Role |
|------|------|
| `app/views/notification_mailer/entry_created.html.erb` | Reference — HTML template pattern to copy |
| `app/views/notification_mailer/entry_created.text.erb` | Reference — text template pattern to copy |
| `app/views/layouts/mailer.html.erb` | Shared — already set up for HTML emails |
| `app/models/comment.rb` | Reference — `body` (plain text), `user`, `journal_entry` |
| `app/jobs/notify_comment_added_job.rb` | Reference — dispatches `comment.id, sub.id` |

### Comment Model Fields

- `body` (text) — **plain text**, not ActionText (unlike `JournalEntry#body` which is rich text)
- `user` (User association) — the commenter, has `name` and `email`
- `journal_entry` (JournalEntry association) — the parent entry
- `created_at` (datetime) — when the comment was posted

### Key Difference from entry_created

The comment `body` is **plain text** (stored as a regular `text` column), NOT ActionText. This means:
- No `sanitize_body_for_email` needed — the body is already plain text
- No `<action-text-attachment>` stripping needed
- No `html_safe` marking needed — use `<%= @comment.body %>` directly in HTML (auto-escaped)
- No `to_plain_text` conversion needed for text template — `@comment.body` is already plain text
- No inline images from the comment itself (comments don't have attachments)

### Design System Colors (hardcoded for email)

From the existing `entry_created.html.erb`:
- Background: `#faf8ff`
- Card: `#ffffff`
- Text: `#131b2e`
- Muted: `#3e484f`
- Primary (button): `#00668a`
- Primary on (button text): `#ffffff`
- Divider: `#e2e8f0`

---

## Implementation Plan

### 1. Update `comment_added` Mailer Method

Add `@entry_url` so templates can link to the entry:

```ruby
def comment_added(comment_id, recipient_id)
  @comment = Comment.find_by(id: comment_id)
  @recipient = User.find_by(id: recipient_id)
  return unless @comment && @recipient

  @entry = @comment.journal_entry
  @trip = @entry.trip
  @commenter = @comment.user
  @entry_url = trip_journal_entry_url(@trip, @entry)

  mail(
    to: @recipient.email,
    subject: "New comment on #{@entry.name} in #{@trip.name}"
  )
end
```

That's the only change needed in the mailer. No `sanitize_body_for_email` (comment body is plain text), no `attach_inline_images` (comments don't have image attachments).

### 2. Create HTML Template (`comment_added.html.erb`)

Follow the exact same table-based layout as `entry_created.html.erb` but adapted for comment content:

- **Header:** Trip name overline, entry title, date + optional location
- **Comment block:** Commenter name + "commented:" label, then the comment body in a styled card/quote block
- **Read Online button:** Same styled button linking to `@entry_url`
- **Footer:** "You received this because you follow this entry."

Structure:
```erb
<table ...>
  <tr>
    <td style="padding: 32px; background-color: #ffffff; border-radius: 16px;">
      <%# Header: trip overline + entry title + date %>
      ...trip name, entry name, entry date + location...

      <%# Commenter info %>
      <td>By <%= @commenter.name || @commenter.email %></td>

      <%# Comment body %>
      <td style="padding: 16px; background-color: #f2f3ff; border-radius: 12px; ...">
        <%= @comment.body %>
      </td>

      <%# Read Online button %>
      <a href="<%= @entry_url %>" style="...">Read Online</a>
    </td>
  </tr>
  <tr>
    <td>You received this because you follow this entry.</td>
  </tr>
</table>
```

Use `#f2f3ff` (from `--ha-bg-alt`) as the comment quote background to visually distinguish the comment body from the entry header.

### 3. Update Text Template (`comment_added.text.erb`)

Mirror the `entry_created.text.erb` structure:

```erb
<%= @commenter.name || @commenter.email %> commented on "<%= @entry.name %>" in the trip "<%= @trip.name %>".

---

<%= @entry.name %>
<%= @entry.entry_date.to_fs(:long) %>
<% if @entry.location_name.present? %><%= @entry.location_name %>
<% end %>
Comment:
<%= @comment.body %>

---

Read Online: <%= @entry_url %>
```

### 4. Expand Mailer Specs

Add comprehensive tests for `#comment_added` matching the `#entry_created` pattern:

```ruby
describe "#comment_added" do
  let(:entry) do
    create(:journal_entry, :with_location,
           trip: trip, author: admin, name: "Test Entry")
  end
  let(:comment) do
    create(:comment,
           journal_entry: entry, user: member, body: "Great post!")
  end
  let(:mail) do
    described_class.comment_added(comment.id, admin.id)
  end

  it "sends to the recipient" do
    expect(mail.to).to eq([admin.email])
  end

  it "sets the subject" do
    expect(mail.subject).to eq(
      "New comment on Test Entry in Japan Trip"
    )
  end

  it "includes entry title in HTML part" do
    html = mail.html_part.body.to_s
    expect(html).to include("Test Entry")
  end

  it "includes comment body in HTML part" do
    html = mail.html_part.body.to_s
    expect(html).to include("Great post!")
  end

  it "includes commenter name in HTML part" do
    html = mail.html_part.body.to_s
    expect(html).to include("Bob")
  end

  it "includes Read Online link in HTML part" do
    html = mail.html_part.body.to_s
    expect(html).to include("Read Online")
  end

  it "includes location in HTML part" do
    html = mail.html_part.body.to_s
    expect(html).to include("Paris, France")
  end

  it "includes comment body in text part" do
    text = mail.text_part.body.to_s
    expect(text).to include("Great post!")
  end

  it "includes Read Online link in text part" do
    text = mail.text_part.body.to_s
    expect(text).to include("Read Online")
  end

  it "returns nil mail when comment not found" do
    result = described_class.comment_added("nonexistent", admin.id)
    expect(result.message).to be_a(ActionMailer::Base::NullMail)
  end

  it "returns nil mail when recipient not found" do
    result = described_class.comment_added(comment.id, "nonexistent")
    expect(result.message).to be_a(ActionMailer::Base::NullMail)
  end
end
```

---

## Tasks (in order)

1. **Update the mailer method** (`app/mailers/notification_mailer.rb`)
   - Add `@entry_url = trip_journal_entry_url(@trip, @entry)` to `comment_added`
   - No other changes needed (comment body is plain text)

2. **Update the text email template** (`app/views/notification_mailer/comment_added.text.erb`)
   - Include entry metadata (name, date, location)
   - Include comment body
   - Change link from `View the entry: <URL>` to `Read Online: <URL>`

3. **Create the HTML email template** (`app/views/notification_mailer/comment_added.html.erb`)
   - Copy the structure from `entry_created.html.erb`
   - Replace entry body section with comment body in a quote-styled block
   - Remove inline images section (comments don't have images)
   - Keep: trip overline, entry title, date/location, commenter info, Read Online button, footer

4. **Expand mailer specs** (`spec/mailers/notification_mailer_spec.rb`)
   - Replace the minimal 2-test `#comment_added` block with comprehensive tests
   - Cover: recipient, subject, HTML content (entry title, comment body, commenter, location, Read Online), text content, nil handling

5. **Run linting and tests**
   - `bundle exec rake project:fix-lint`
   - `bundle exec rake project:lint`
   - `bundle exec rake project:tests`
   - `bundle exec rake project:system-tests`

6. **Live verification**
   - `bin/cli app rebuild && bin/cli app restart && bin/cli mail start`
   - Create a comment on a journal entry
   - Verify email in MailCatcher:
     - HTML version shows entry context + comment body + Read Online button
     - Text version shows entry context + comment body + Read Online link
     - Footer says "you follow this entry" (not "member of the trip")

---

## Gotchas & Edge Cases

1. **Comment body is plain text, NOT ActionText.** Do NOT use `sanitize_body_for_email`, `to_plain_text`, or `html_safe` on comment body. Just `<%= @comment.body %>` which ERB auto-escapes in HTML and renders as-is in text.

2. **No inline images for comments.** Comments don't have `has_many_attached :images`. Do NOT call `attach_inline_images` in `comment_added`.

3. **Multi-part email auto-detection.** Creating `comment_added.html.erb` alongside the existing `.text.erb` will automatically make Rails send `multipart/alternative` emails. No mailer code changes needed for this.

4. **Shared HTML layout.** The `mailer.html.erb` layout already provides the centered 600px wrapper. The new HTML template just needs the content block.

5. **Footer text differs.** Entry emails say "you are a member of the trip". Comment emails should say "you follow this entry" since notifications go to entry subscribers, not all trip members (see `notify_comment_added_job.rb` line 11: `entry.subscribers`).

6. **ERB linter.** Do NOT use `raw()` in the template — the comment body is plain text and should be auto-escaped by ERB. The entry_created template needed `raw` for ActionText HTML; comments don't.

7. **Bullet N+1.** The mailer loads `@comment.journal_entry` and `@entry.trip` — these are single-record loads, not collections. No eager loading needed (Bullet would flag unused includes).

---

## Files Changed Summary

| File | Change Type | Description |
|------|-------------|-------------|
| `app/mailers/notification_mailer.rb` | Modified | Add `@entry_url` to `comment_added` |
| `app/views/notification_mailer/comment_added.text.erb` | Modified | Full content with entry context + comment body |
| `app/views/notification_mailer/comment_added.html.erb` | Created | HTML email mirroring entry_created pattern |
| `spec/mailers/notification_mailer_spec.rb` | Modified | Expand comment_added tests to match entry_created coverage |

---

## Workflow

Follow the `/execution-plan` skill:
1. Create GitHub issue
2. Move to Kanban board
3. Create feature branch
4. Implement changes (tasks 1-4)
5. Run tests + linting (task 5)
6. Live verification (task 6)
7. Push branch and create PR

---

## Quality Checklist

- [x] All necessary context included (current mailer code, both templates, model fields, test patterns)
- [x] Validation gates are executable by AI (test commands, spec patterns, lint commands)
- [x] References existing patterns (entry_created is the exact template to copy)
- [x] Clear implementation path (4 ordered tasks with pseudocode)
- [x] Error handling documented (7 gotchas — plain text vs ActionText, no images, footer text, ERB linter)
- [x] Scope is clear (comment_added only, minimal changes to mailer method)
