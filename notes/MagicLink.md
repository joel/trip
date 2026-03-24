# Magic Link

db = Sequel.sqlite(extensions: :activerecord_connection, keep_reference: false)
key_row = db[:user_email_auth_keys].where(id: user.id).first
key = key_row ? key_row[:key] : nil

unless key
  key = SecureRandom.urlsafe_base64(32)
  db[:user_email_auth_keys].insert(id: user.id, key: key, deadline: Time.now + 3600, email_last_sent: Time.now)
end

puts "https://catalyst.workeverywhere.app/email-auth?key=#{user.id}_#{key}"

# Account Verification Link

vk = db[:user_verification_keys].where(id: user.id).first
vkey = vk ? vk[:key] : nil

unless vkey
  vkey = SecureRandom.urlsafe_base64(32)
  db[:user_verification_keys].insert(id: user.id, key: vkey, requested_at: Time.now, email_last_sent: Time.now)
end

puts "https://catalyst.workeverywhere.app/verify-account?key=#{user.id}_#{vkey}"

# If the user is already verified, we can just skip the verification step and go straight to email auth

# Set account to verified status (Rodauth uses status 2 for verified)
# But first check if there's a mismatch - let's just force it
user.update!(status: 2)

# Clear any stale verification keys
db[:user_verification_keys].where(id: user.id).delete

# Now create a fresh email auth key and use it
db[:user_email_auth_keys].where(id: user.id).delete
key = SecureRandom.urlsafe_base64(32)
db[:user_email_auth_keys].insert(id: user.id, key: key, deadline: Time.now + 3600, email_last_sent: Time.now)

puts "https://catalyst.workeverywhere.app/email-auth?key=#{user.id}_#{key}"

# Trigger the real email auth flow programmatically
rodauth = Rodauth::Rails.rodauth(:main, account: user)
rodauth.create_email_auth_key
key = rodauth.email_auth_key_value
puts "https://catalyst.workeverywhere.app/email-auth?key=#{user.id}_#{key}"

# If that doesn't work (Rodauth's rodauth() helper may need a request context), the nuclear option — just mark the user as logged in by skipping email auth entirely:

# Just auto-verify and check current state
db[:user_email_auth_keys].where(id: user.id).delete
# Check what key Rodauth actually stored
db[:user_email_auth_keys].all
