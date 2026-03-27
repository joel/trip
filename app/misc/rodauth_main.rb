# frozen_string_literal: true

require "sequel/core"

class RodauthMain < Rodauth::Rails::Auth
  unless BuildTasks.assets_precompile?
    configure do # rubocop:disable Metrics/BlockLength
      enable :create_account, :verify_account, :login, :logout,
             :email_auth, :webauthn, :webauthn_login, :omniauth

      db Sequel.sqlite(extensions: :activerecord_connection, keep_reference: false)

      accounts_table :users
      verify_account_table :user_verification_keys
      email_auth_table :user_email_auth_keys
      webauthn_keys_table :user_webauthn_keys
      webauthn_user_ids_table :user_webauthn_user_ids
      webauthn_keys_account_id_column :user_id

      # OmniAuth (Google social login)
      omniauth_identities_table :user_omniauth_identities
      omniauth_identities_account_id_column :user_id

      if ENV["GOOGLE_CLIENT_ID"].present?
        omniauth_provider :google_oauth2,
                          ENV["GOOGLE_CLIENT_ID"],
                          ENV.fetch("GOOGLE_CLIENT_SECRET", nil),
                          name: :google,
                          scope: "email,profile"
      end

      omniauth_create_account? false
      omniauth_verify_account? true

      rails_controller { RodauthController }
      title_instance_variable :@page_title

      account_status_column :status
      login_param "email"
      login_label "Email"
      login_confirm_param "email-confirm"
      need_password_notice_flash "Email recognized. Choose how to sign in."
      email_auth_email_sent_notice_flash "A sign-in link has been sent to your email. Check your inbox."
      email_auth_email_sent_redirect { login_path }

      create_account_set_password? false
      verify_account_set_password? false
      require_login_confirmation? false
      require_password_confirmation? false
      require_bcrypt? false

      auth_class_eval do
        def two_factor_authentication_setup?
          false
        end

        def get_password_hash
          nil
        end

        def before_create_account
          super
          validate_invitation_token
          account[:id] ||= SecureRandom.uuid
          timestamp = Time.current
          account[:created_at] ||= timestamp
          account[:updated_at] ||= timestamp
        end

        def validate_invitation_token
          token = param_or_nil("invitation_token")
          email = param(login_param)
          invitation = token && ::Invitation.valid_tokens.find_by(token: token)
          return if invitation && invitation.email.downcase == email.to_s.downcase

          set_redirect_error_flash "A valid invitation is required to create an account."
          redirect create_account_path
        end

        def verify_account_view
          return super if verify_account_set_password? || !account

          transaction do
            before_verify_account
            verify_account
            clear_tokens(:verify_account)
            after_verify_account
          end

          autologin_session("verify_account") if verify_account_autologin?
          remove_session_value(verify_account_session_key)
          verify_account_response
        end
      end

      email_from do
        ENV.fetch("RODAUTH_FROM", ENV.fetch("NOTIF_MAIL_FROM", "catalyst@joelazemar.com"))
      end

      create_verify_account_email do
        RodauthMailer.verify_account(self.class.configuration_name, account_id, verify_account_key_value)
      end

      create_email_auth_email do
        RodauthMailer.email_auth(self.class.configuration_name, account_id, email_auth_key_value)
      end

      send_email do |email|
        db.after_commit { email.deliver_later }
      end

      webauthn_origin { ENV.fetch("WEBAUTHN_ORIGIN", base_url) }
      webauthn_rp_id do
        ENV.fetch("WEBAUTHN_RP_ID", webauthn_origin.sub(%r{\Ahttps?://}, "").sub(/:\d+\z/, ""))
      end
      webauthn_rp_name { ENV.fetch("WEBAUTHN_RP_NAME", "Catalyst") }
      webauthn_user_verification "preferred"

      after_create_account do
        token = param_or_nil("invitation_token")
        return unless token

        ::Invitations::Accept.new.call(token: token, email: account[login_column])
      end

      # OmniAuth hooks
      omniauth_login_failure_redirect { login_path }

      before_omniauth_callback_route do
        return if omniauth_email.blank?

        user = ::User.find_by(id: account_id)
        user&.update!(name: omniauth_name) if user&.name.blank? && omniauth_name.present?
      end

      logout_redirect "/"
      verify_account_redirect { login_redirect }
    end
  end
end
