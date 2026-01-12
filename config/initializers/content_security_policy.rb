# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, :data
    # Allow images from HTTPS sources (for RSS feed article images)
    policy.img_src     :self, :https, :data
    policy.object_src  :none
    policy.script_src  :self
    # unsafe_inline needed for Turbo's dynamically injected styles
    policy.style_src   :self, :unsafe_inline
    # Allow connecting to self and any HTTPS for fetching feeds
    policy.connect_src :self, :https
    policy.frame_ancestors :none
    policy.base_uri    :self
    policy.form_action :self
  end

  # Generate session nonces for permitted importmap, inline scripts, and inline styles.
  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  config.content_security_policy_nonce_directives = %w[script-src]

  # Report violations without enforcing the policy initially (can be removed once tested).
  # config.content_security_policy_report_only = true
end
