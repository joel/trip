Security Review — feature/phase4-authorization

  Authentication & Authorization

  - All new routes protected by require_authenticated_user! — all 3 controllers have it as first before_action
  - Authorization checks present via authorize! — all 3 controllers add before_action :authorize_*! running on every action
  - Policies correctly check roles — superadmin? from ApplicationPolicy, membership lookup via live DB query (find_by/exists?)
  - Can a user bypass authorization by crafting a direct HTTP request? — No. authorize! runs as before_action on every action, not just UI-gated actions
  - [N/A] Invitation/token flows — no token flows in this diff

  Input & Output

  - Strong parameters enforced — existing params.expect unchanged, no new param handling
  - Output escaped — Phlex auto-escaping. Pre-existing unsafe_raw at journal_entries/show.rb:79 for Action Text body is not new in this diff
  - [N/A] File uploads — no upload changes in this diff
  - [N/A] User input validation — no new input acceptance

  Data Exposure

  - No private fields exposed in views — only allowed_to? checks added, no new data rendering
  - Error messages generic — head :forbidden (bare 403, no body) from ApplicationController rescue
  - Logs clean — no new logging of sensitive values

  Mass Assignment & Query Safety

  - No raw SQL fragments
  - Policy checks run before every mutation — before_action ordering verified: auth → set record → authorize → action body
  - Nested resources parent-scoped — @trip.journal_entries.find(params[:id]) and @trip.trip_memberships.find(params[:id]) ensure entries/memberships belong to the trip in the URL

  Secrets & Configuration

  - No secrets in diff
  - No .env or credentials files touched
  - [N/A] No new environment variables

  Dependencies

  - No new gems added (Gemfile/Gemfile.lock unchanged)

  ---
  Warning (should fix or consciously accept)

  - Resource existence leakage via 404 vs 403: app/controllers/trips_controller.rb:5-6 — set_trip runs before authorize_trip!. If an authenticated non-member hits /trips/<existing-uuid>, they get
  403. If they hit /trips/<non-existent-uuid>, Rails raises ActiveRecord::RecordNotFound (404 in production). This difference reveals whether a trip UUID exists. The same pattern applies to
  JournalEntriesController and TripMembershipsController.

  - Risk: Low. UUIDs are not enumerable (128-bit random), so brute-forcing existence is infeasible. This is a standard Rails pattern and matches the existing UsersController behavior. However, if you
   want defense-in-depth, you could add rescue_from ActiveRecord::RecordNotFound { head :not_found } or reorder to authorize before set (harder with ActionPolicy since it needs the record).

  - Recommendation: Accept consciously. Document as known behavior. The UUID space makes this unexploitable in practice.

  Informational (no action required)

  - The TripsController#index correctly scopes queries: superadmin sees Trip.all, others see current_user.trips. This is enforced at the query level, not the policy level (no ActionPolicy scope).
  This is intentional per the Phase 4 plan — the policy's index? only checks user.present?.
  - Membership removal takes effect immediately because policies do live DB queries (find_by/exists?) — no caching layer to worry about.
  - TripPolicy#trip_membership guards with record.is_a?(Trip) which correctly returns nil when authorize!(Trip) passes the class for index/new/create actions. This prevents accidental membership
  lookups on class objects.
  - Pre-existing unsafe_raw at journal_entries/show.rb:79 renders Action Text HTML. This is not new in this diff and is standard for Action Text. Action Text sanitizes on input via the Trix editor.

  Not applicable

  - File uploads — no upload changes
  - Invitation/token flows — no token handling
  - Dependencies — no new gems

  Verdict: No critical issues. One low-risk warning (404/403 information leakage) that is acceptable given UUID primary keys. The authorization implementation is sound — policies are correctly
  enforced server-side, UI guards are defense-in-depth only, and the before_action ordering prevents any mutation from executing before authorization.
