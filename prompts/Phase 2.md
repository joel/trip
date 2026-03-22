# Instructions

The PR has been merged. Please check out the base branch, pull the latest changes, draft the Phase 2 plan for validation, and wait for my approval before starting anything.

Read CLAUDE.md and use the project skill /github-workflow to execute the Phase.

Please go through the PR comments and share your thoughts.

Please follow the process described in CLAUDE.md and project skill /github-workflow

Fix one by one (commit) the comments
Reply to the comments so we leave a clear trace
Mark Comversation as resolved.

Use the project skill /runtime-test and check that everything is working as expected.

# Phase 2: Access and Onboarding Flow

 Context

 Phase 1 established the foundation (gems, roles, BaseAction, Action Text, PWA). Phase 2 builds the invite-only access system: public visitors request access, superadmins review requests and send
 invitations, invited users create accounts via a Rodauth feature plugin that validates invitation tokens during signup. This is the gateway to the entire app — no user can exist without going
 through this flow.

 User Decisions

 - Invitation flow: Custom Rodauth feature plugin that adds invitation token validation to create_account
 - Landing page: Separate /request-access route (current home page stays as-is)
 - Admin review: Standalone /access_requests section with dedicated sidebar nav item

 Scope

 Models & Migrations

 1. AccessRequest — public email submission, admin review
 2. Invitation — admin sends invite with secure token, user accepts during signup

 Actions (Dry::Monads)

 3. AccessRequests::Submit — public form, emits access_request.submitted
 4. AccessRequests::Approve — superadmin approves, emits access_request.approved
 5. AccessRequests::Reject — superadmin rejects, emits access_request.rejected
 6. Invitations::Send — superadmin sends invite, emits invitation.sent
 7. Invitations::Accept — called from Rodauth hook, emits invitation.accepted

 Policies

 8. AccessRequestPolicy — public create, superadmin for index/approve/reject
 9. InvitationPolicy — superadmin for create/index, no direct user access

 Controllers & Views

 10. AccessRequestsController — public new/create, admin index/approve/reject
 11. InvitationsController — admin index/new/create
 12. Public landing page view at /request-access
 13. Admin access request list with approve/reject actions
 14. Admin invitation list with send form

 Rodauth Integration

 15. Custom Rodauth feature: invitation — validates token param during create_account

 Mailers

 16. AccessRequestMailer — notify superadmin of new request
 17. InvitationMailer — send invitation link to invitee
 18. OnboardingMailer — notify superadmin after user signs up

 Events & Subscribers

 19. Wire up events to subscribers that trigger mailer jobs

 Navigation

 20. Add "Access Requests" and "Invitations" nav items to sidebar (superadmin only)

 ---
 Files to Create

 Migrations

 - db/migrate/TIMESTAMP_create_access_requests.rb
 - db/migrate/TIMESTAMP_create_invitations.rb

 Models

 - app/models/access_request.rb
 - app/models/invitation.rb

 Actions

 - app/actions/access_requests/submit.rb
 - app/actions/access_requests/approve.rb
 - app/actions/access_requests/reject.rb
 - app/actions/invitations/send_invitation.rb
 - app/actions/invitations/accept.rb

 Policies

 - app/policies/access_request_policy.rb
 - app/policies/invitation_policy.rb

 Controllers

 - app/controllers/access_requests_controller.rb
 - app/controllers/invitations_controller.rb

 Views (Phlex)

 - app/views/access_requests/new.rb — public request form
 - app/views/access_requests/index.rb — admin review list
 - app/views/invitations/index.rb — admin invitation list
 - app/views/invitations/new.rb — admin send invitation form

 Components (Phlex)

 - app/components/access_request_form.rb
 - app/components/access_request_card.rb
 - app/components/invitation_form.rb
 - app/components/invitation_card.rb

 Rodauth Feature

 - app/misc/rodauth_invitation.rb — custom feature plugin

 Mailers

 - app/mailers/access_request_mailer.rb
 - app/mailers/invitation_mailer.rb
 - app/mailers/onboarding_mailer.rb
 - app/views/access_request_mailer/new_request.text.erb
 - app/views/invitation_mailer/invite.text.erb
 - app/views/onboarding_mailer/signup_notification.text.erb

 Subscribers & Jobs

 - app/subscribers/access_request_subscriber.rb
 - app/subscribers/invitation_subscriber.rb
 - app/subscribers/onboarding_subscriber.rb
 - app/jobs/notify_admin_of_access_request_job.rb
 - app/jobs/send_invitation_email_job.rb
 - app/jobs/notify_admin_of_signup_job.rb

 Factories & Specs

 - spec/factories/access_requests.rb
 - spec/factories/invitations.rb
 - spec/models/access_request_spec.rb
 - spec/models/invitation_spec.rb
 - spec/actions/access_requests/submit_spec.rb
 - spec/actions/access_requests/approve_spec.rb
 - spec/actions/access_requests/reject_spec.rb
 - spec/actions/invitations/send_invitation_spec.rb
 - spec/actions/invitations/accept_spec.rb
 - spec/policies/access_request_policy_spec.rb
 - spec/policies/invitation_policy_spec.rb
 - spec/requests/access_requests_spec.rb
 - spec/requests/invitations_spec.rb
 - spec/system/access_requests_spec.rb
 - spec/system/invitations_spec.rb

 Files to Modify

 - config/routes.rb — add access_requests, invitations routes
 - config/initializers/event_subscribers.rb — register subscribers
 - app/misc/rodauth_main.rb — enable invitation feature, add after_create_account hook
 - app/components/sidebar.rb — add Access Requests + Invitations nav items for superadmin
 - app/views/welcome/home.rb — add "Request Access" link for logged-out visitors
 - db/seeds.rb — seed a superadmin user

 ---
 Implementation Details

 1. AccessRequest Model

 # Migration
 create_table :access_requests, id: :uuid do |t|
   t.string :email, null: false
   t.integer :status, null: false, default: 0
   t.references :reviewed_by, type: :uuid, foreign_key: { to_table: :users }, null: true
   t.datetime :reviewed_at
   t.timestamps
 end
 add_index :access_requests, :email

 # Model
 class AccessRequest < ApplicationRecord
   enum :status, { pending: 0, approved: 1, rejected: 2 }
   belongs_to :reviewed_by, class_name: "User", optional: true
   validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
   scope :pending, -> { where(status: :pending) }
 end

 2. Invitation Model

 # Migration
 create_table :invitations, id: :uuid do |t|
   t.references :inviter, type: :uuid, null: false, foreign_key: { to_table: :users }
   t.string :email, null: false
   t.string :token, null: false
   t.integer :status, null: false, default: 0
   t.datetime :accepted_at
   t.datetime :expires_at, null: false
   t.timestamps
 end
 add_index :invitations, :token, unique: true
 add_index :invitations, :email

 # Model
 class Invitation < ApplicationRecord
   enum :status, { pending: 0, accepted: 1, expired: 2 }
   belongs_to :inviter, class_name: "User"
   has_secure_token :token
   validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
   validates :expires_at, presence: true
   scope :pending, -> { where(status: :pending) }
   scope :valid, -> { pending.where("expires_at > ?", Time.current) }

   def expired?
     expires_at <= Time.current
   end

   def accept!
     update!(status: :accepted, accepted_at: Time.current)
   end
 end

 3. Rodauth Invitation Feature

 Create app/misc/rodauth_invitation.rb as a module that hooks into before_create_account to validate the invitation token from params:

 # In rodauth_main.rb, add to configure block:
 #   after_create_account do
 #     token = param_or_nil("invitation_token")
 #     if token
 #       invitation = Invitation.valid.find_by(token: token)
 #       invitation&.accept! if invitation
 #     end
 #   end

 The key integration points in rodauth_main.rb:
 - after_create_account — accept the invitation, emit event, trigger post-signup notification
 - create_account_redirect — redirect to root after account creation
 - No changes to before_create_account (UUID generation stays)

 The create_account page URL becomes: /create-account?invitation_token=xxx

 For non-invited signups: Rodauth's default create_account still works (existing behavior). The invitation token is simply optional — if present, the invitation is marked accepted.

 4. Action Pattern

 All actions follow BaseAction with Dry::Monads:

 module AccessRequests
   class Submit < BaseAction
     def call(params:)
       access_request = yield persist(params)
       yield emit_event(access_request)
       Success(access_request)
     end

     private

     def persist(params)
       ar = AccessRequest.create!(email: params[:email])
       Success(ar)
     rescue ActiveRecord::RecordInvalid => e
       Failure(e.record.errors)
     end

     def emit_event(access_request)
       Rails.event.notify("access_request.submitted",
         access_request_id: access_request.id, email: access_request.email)
       Success()
     end
   end
 end

 5. Controller Pattern

 class AccessRequestsController < ApplicationController
   skip_before_action :verify_authenticity_token, only: [] # none needed
   before_action :require_authenticated_user!, only: %i[index approve reject]
   before_action :set_access_request, only: %i[approve reject]
   before_action :authorize_access_request!, only: %i[index approve reject]

   # GET /request-access (public)
   def new
     @access_request = AccessRequest.new
     render Views::AccessRequests::New.new(access_request: @access_request)
   end

   # POST /request-access (public)
   def create
     result = AccessRequests::Submit.new.call(params: access_request_params)
     case result
     in Success
       redirect_to root_path, notice: "Your access request has been submitted."
     in Failure(errors)
       @access_request = AccessRequest.new(access_request_params)
       @access_request.errors.merge!(errors)
       render Views::AccessRequests::New.new(access_request: @access_request),
              status: :unprocessable_content
     end
   end

   # GET /access_requests (superadmin)
   def index
     @access_requests = AccessRequest.order(created_at: :desc)
     render Views::AccessRequests::Index.new(access_requests: @access_requests)
   end

   # ...approve/reject actions
 end

 6. Routes

 # Public
 get "request-access", to: "access_requests#new", as: :new_access_request
 post "request-access", to: "access_requests#create", as: :access_requests_submit

 # Admin
 resources :access_requests, only: [:index] do
   member do
     patch :approve
     patch :reject
   end
 end
 resources :invitations, only: %i[index new create]

 7. Mailers

 Three mailers, all inheriting from ApplicationMailer:
 - AccessRequestMailer#new_request — to superadmin(s), "New access request from {email}"
 - InvitationMailer#invite — to invitee, includes invitation URL with token
 - OnboardingMailer#signup_notification — to superadmin(s), "{email} has signed up"

 8. Events & Subscribers

 # config/initializers/event_subscribers.rb
 Rails.application.config.after_initialize do
   Rails.event.subscribe("access_request.submitted", AccessRequestSubscriber)
   Rails.event.subscribe("access_request.approved", AccessRequestSubscriber)
   Rails.event.subscribe("invitation.sent", InvitationSubscriber)
   Rails.event.subscribe("invitation.accepted", OnboardingSubscriber)
 end

 9. Sidebar Navigation

 Add to render_main_nav in sidebar, after Users link (superadmin only):
 - "Access Requests" → /access_requests with badge showing pending count
 - "Invitations" → /invitations

 10. Welcome Page Update

 Add a "Request Access" link to the logged-out hero section in app/views/welcome/home.rb, replacing the current "Create account" button in render_signin_card.

 ---
 Verification

 Automated Tests

 mise x -- bundle exec rake project:tests
 mise x -- bundle exec rake project:system-tests
 mise x -- bundle exec rake project:lint

 Runtime Test Checklist

 - /request-access renders for unauthenticated visitors
 - Submitting access request shows success flash
 - Superadmin receives notification email (check mail service)
 - Superadmin sees pending requests at /access_requests
 - Approve/reject actions work and update status
 - Superadmin can send invitation from /invitations/new
 - Invitee receives invitation email with signup link
 - Invitation link leads to /create-account?invitation_token=xxx
 - Creating account with valid token marks invitation as accepted
 - Superadmin receives signup notification email
 - Sidebar shows Access Requests + Invitations for superadmin only
 - Dark mode works on all new pages
 - No runtime errors

 Definition of Done (from PRP)

 - Public visitor can submit access request
 - Super admin receives email notification
 - Super admin can approve/reject requests
 - Super admin can send invitation with secure token
 - Invited user can create account via invitation link
 - Super admin notified after signup
 - All actions emit structured events
 - Policy tests cover all access patterns
 - Request and system tests pass
╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌

# Summary

Phase 2 complete. Here's the summary:

  PR https://github.com/joel/trip/pull/13 — Phase 2: Access and Onboarding Flow

  55 files changed, 1411 insertions across:

  ┌─────────────┬─────────────────────────────────────────────────────────────────────────┐
  │    Area     │                                  Files                                  │
  ├─────────────┼─────────────────────────────────────────────────────────────────────────┤
  │ Models      │ AccessRequest, Invitation (with migrations)                             │
  ├─────────────┼─────────────────────────────────────────────────────────────────────────┤
  │ Actions     │ 5 Dry::Monads actions (Submit, Approve, Reject, SendInvitation, Accept) │
  ├─────────────┼─────────────────────────────────────────────────────────────────────────┤
  │ Policies    │ AccessRequestPolicy, InvitationPolicy                                   │
  ├─────────────┼─────────────────────────────────────────────────────────────────────────┤
  │ Controllers │ AccessRequestsController, InvitationsController                         │
  ├─────────────┼─────────────────────────────────────────────────────────────────────────┤
  │ Views       │ 4 Phlex views + 4 Phlex components                                      │
  ├─────────────┼─────────────────────────────────────────────────────────────────────────┤
  │ Mailers     │ 3 mailers + 3 email templates                                           │
  ├─────────────┼─────────────────────────────────────────────────────────────────────────┤
  │ Events      │ 3 subscribers using Rails.event #emit with filter blocks                │
  ├─────────────┼─────────────────────────────────────────────────────────────────────────┤
  │ Jobs        │ 3 background jobs for email delivery                                    │
  ├─────────────┼─────────────────────────────────────────────────────────────────────────┤
  │ Specs       │ 47 new examples (101 total, 0 failures)                                 │
  └─────────────┴─────────────────────────────────────────────────────────────────────────┘

  Key integration: Rodauth after_create_account hook validates invitation tokens — when a user signs up via /create-account?invitation_token=xxx, the invitation is automatically marked as accepted.

  Discovery during implementation: Rails 8.1.2's Rails.event.subscribe takes a single subscriber argument (must respond to #emit) with an optional filter block — not (event_name, subscriber) as
  documented in some guides. The subscriber's #emit method receives a hash with [:name], [:payload], etc.

  # PR Reviews

  Three review comments. Here are my thoughts:

  ---
  Comment 1 (P1): "Block account creation when the invitation token is missing or bad"

  Verdict: Valid and important. This is a real security gap. The after_create_account hook runs after the account already exists, and we silently ignore failures. Anyone can bypass the invite-only
  flow by going directly to /create-account.

  Fix: Move the validation to before_create_account instead of after_create_account. If no valid invitation_token param is present, raise an error or call set_redirect_error_flash and halt the
  account creation. This makes the invite gate enforced before the user row is inserted.

  However, there's a nuance — the existing Rodauth config already allows account creation without a token (that's the default flow for the app owner's first account, seeded users, etc.). We need a
  way to bootstrap the first superadmin. Two options:
  1. Use db/seeds.rb to create the initial superadmin directly (bypassing Rodauth), then enforce token requirement in Rodauth
  2. Add an ENV flag like ALLOW_OPEN_SIGNUP=true for initial setup

  I'd go with option 1 — seeds create the superadmin, before_create_account enforces invitation tokens for all subsequent signups.

  ---
  Comment 2 (P1): "Bind invitation acceptance to the email being registered"

  Verdict: Valid. Currently Invitations::Accept only checks the token, not whether the signup email matches invitation.email. A forwarded link could be used by anyone.

  Fix: Pass the registering email to Invitations::Accept and validate it matches invitation.email (case-insensitive). In the Rodauth hook, we have access to account[:email] (the email being
  registered) so we can pass it through.

  ---
  Comment 3 (P2): "Show expired invites as expired instead of leaving them pending"

  Verdict: Valid. The expired status is never set — valid_tokens scope just excludes them from queries, but the persisted status stays pending. Admins see stale "Pending" badges.

  Fix: Two approaches:
  1. Display-level fix (simpler): In InvitationCard, check invitation.expired? and show "Expired" badge regardless of persisted status
  2. Background job (proper): Add a recurring job in config/recurring.yml to sweep expired invitations and update their status

  I'd do both — the display fix is instant feedback, and the background sweep keeps the data clean for queries.

