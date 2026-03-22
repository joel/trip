UX Review — feature/phase4-authorization

  Broken (blocks usability)

  None found.

  Friction (degrades experience)

  - Blank 403 page for unauthorized access: When a non-member navigates directly to a trip URL (e.g. from a shared link or bookmarked URL), they see a completely blank white page. No sidebar, no
  error message, no "go back" link. The head :forbidden response sends a bare 403 status with no body. While this is secure (no information leakage), it's a dead end for the user — they have no idea
  what happened or how to recover. Recommended fix: Add a Views::Shared::Forbidden page (similar to the existing Views::Shared::Unauthorized which renders a proper 401 page with layout and message)
  that says "You don't have permission to view this page" with a link back to trips or home.

  Suggestions (nice to have)

  - The "Members" link on the trip show page is always visible to any member (intentional per spec), but there's no visual cue that it's read-only for non-admins vs actionable for admins. A minor
  label change like "View members" for non-admins could set clearer expectations, but this is cosmetic.

  Authorization-Aware UI Checklist

  - "New trip" button hidden for non-superadmin (verified: contributor and viewer)
  - "Edit" button on trip card hidden for viewer (verified)
  - "Edit"/"Delete" buttons on trip show hidden for viewer (verified)
  - State transition buttons hidden for non-superadmin (verified: contributor and viewer)
  - "New entry" button hidden for viewer (verified)
  - "Edit" button on entry card hidden for viewer (verified)
  - "Edit"/"Delete" on entry show hidden for viewer (verified)
  - "Add member" button hidden for non-superadmin (verified: contributor)
  - "Remove" buttons hidden for non-superadmin (verified: contributor)
  - "Members" link remains visible for viewer (verified — intentional)
  - Empty state ("No trips yet") renders correctly for outsider with no memberships
  - No phantom buttons leading to 403 errors (all UI elements match server-side permissions)

  Screenshots reviewed

  - Trips index: admin, contributor, viewer, outsider (light mode)
  - Trip show: admin, contributor, viewer (light mode + dark mode)
  - Journal entry show: admin, contributor, viewer (light mode)
  - Trip memberships index: admin, contributor (light mode)
  - 403 page: outsider accessing forbidden trip
  - Mobile viewport: not testable (agent-browser viewport resize not available on this platform)

  ---
  Should I fix the blank 403 page now, or create a follow-up issue? This is a friction item, not a blocker — the security behavior is correct, only the UX is poor.

# Fix 403

Now let me check how the 401 is rendered in the controller to match the pattern.

  Read 1 file (ctrl+o to expand)

● Good. I'll create the Forbidden view following the same pattern, then update the rescue_from.

● Write(app/views/shared/forbidden.rb)
  ⎿  Wrote 36 lines to app/views/shared/forbidden.rb
       1 # frozen_string_literal: true
       2
       3 module Views
       4   module Shared
       5     class Forbidden < Views::Base
       6       include Phlex::Rails::Helpers::LinkTo
       7
       8       def view_template
       9         div(
      10           class: "mx-auto max-w-xl rounded-3xl border border-white/10 " \
     … +26 lines (ctrl+o to expand)
  ⎿  PostToolUse:Write hook error

● Update(app/controllers/application_controller.rb)
  ⎿  Added 6 lines, removed 1 line
       8    authorize :user, through: :current_user
       9
      10    rescue_from ActionPolicy::Unauthorized do
      11 -    head :forbidden
      11 +    respond_to do |format|
      12 +      format.html do
      13 +        render Views::Shared::Forbidden.new, status: :forbidden
      14 +      end
      15 +      format.any { head :forbidden }
      16 +    end
      17    end
      18
      19    # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  ⎿  PostToolUse:Edit hook error

● Now run tests to make sure nothing breaks.

● Bash(mise x -- bundle exec rake project:tests 2>&1 | tail -10)
  ⎿  PreToolUse:Bash hook error
  ⎿       # Not yet implemented
          # ./spec/helpers/users_helper_spec.rb:14
     … +6 lines (ctrl+o to expand)
  ⎿  (timeout 5m)

● Bash(mise x -- bundle exec rake project:lint 2>&1 | tail -5)
  ⎿  PreToolUse:Bash hook error
  ⎿  No errors were found in ERB files
     bundle exec rubocop --lint --parallel --format simple

     248 files inspected, no offenses detected
  ⎿  (timeout 2m)

● All pass. Let me rebuild and verify the fix visually.

● Bash(bin/cli app rebuild 2>&1 | tail -3)
  ⎿  PreToolUse:Bash hook error
  ⎿  [9df650fb-3b16-4318-ad42-8549d8bc7250] Completed 200 OK in 16ms (Views: 8.0ms | ActiveRecord: 0.0ms (0 queries, 0 cached) | GC: 9.9ms)
  ⎿  (timeout 2m)

● Bash(bin/cli app restart 2>&1 | tail -3)
  ⎿  PreToolUse:Bash hook error
  ⎿  [459af2a8-d95e-465c-82ea-133fe97d692e] Completed 200 OK in 17ms (Views: 9.3ms | ActiveRecord: 0.0ms (0 queries, 0 cached) | GC: 11.2ms)
  ⎿  (timeout 1m)

● Bash(# Log in as outsider again to test the 403 page
      curl -sk -X DELETE https://mail.workeverywhere.docker/messages > /dev/null…)
  ⎿  PreToolUse:Bash hook error
  ⎿  ✓ Catalyst
       https://catalyst.workeverywhere.docker/login
     - textbox "Email" [ref=e5]
     … +7 lines (ctrl+o to expand)
  ⎿  (timeout 20s)

● Bash(# Navigate to forbidden trip
      agent-browser open "https://catalyst.workeverywhere.docker/trips/019d16a4-1060-7d9b-a8fe-aab4bbfc50a4" 2>&1 | tail -3…)
  ⎿  PreToolUse:Bash hook error
  ⎿  ✓ Catalyst
       https://catalyst.workeverywhere.docker/trips/019d16a4-1060-7d9b-a8fe-aab4bbfc50a4
     ✓ Screenshot saved to /tmp/ux-outsider-403-fixed.png

  Read 1 file (ctrl+o to expand)

● The 403 page now renders with the full layout — sidebar, card with "Access denied" heading (partially visible at top), "You don't have permission to access this page." message, and two action
  buttons: "Go to trips" (primary) and "Go home" (secondary). Let me also verify dark mode.

● Bash(agent-browser snapshot -i 2>&1 | grep "dark mode"
      agent-browser click @e3 2>&1 | tail -2…)
  ⎿  PreToolUse:Bash hook error
  ⎿  - button "Toggle dark mode" [ref=e3]
     ✓ Done
     ✓ Screenshot saved to /tmp/ux-outsider-403-dark.png

  Read 1 file (ctrl+o to expand)

● Dark mode looks great — "Access denied" heading clearly visible, message readable, buttons have good contrast. Let me close the browser and commit.

● Bash(agent-browser close 2>&1 | tail -2)
  ⎿  PreToolUse:Bash hook error
  ⎿  ✓ Browser closed

● Now commit and push.

● Bash(git add app/views/shared/forbidden.rb app/controllers/application_controller.rb && git commit -m "$(cat <<'EOF'
      Add friendly 403 Forbidden page with layout and…)
  ⎿  PreToolUse:Bash hook error
  ⎿  Running pre-commit hooks
     Check for trailing whitespace....................[TrailingWhitespace] OK
     Check for "token" strings.....................................[FixMe] OK
     … +15 lines (ctrl+o to expand)
  ⎿  (timeout 30s)

● Bash(unset GITHUB_TOKEN && git push 2>&1 | tail -3)
  ⎿  PreToolUse:Bash hook error
  ⎿  To github.com:joel/trip.git
        3a389cb..826998f  feature/phase4-authorization -> feature/phase4-authorization

● Done. Here's what was fixed:

  - Created app/views/shared/forbidden.rb — a Phlex view matching the existing Unauthorized page pattern, showing "Access denied", a message, and "Go to trips" / "Go home" buttons
  - Updated app/controllers/application_controller.rb — the rescue_from ActionPolicy::Unauthorized now renders the full layout with the Forbidden view for HTML requests, while still returning bare
  head :forbidden for non-HTML (API) requests
  - Verified visually in both light and dark mode — card renders with proper contrast and navigation
  - All 216 tests pass, lint clean, committed as 826998f and pushed

✻ Cogitated for 2m 54s