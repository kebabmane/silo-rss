# Configure Mission Control Jobs
MissionControl::Jobs.base_controller_class = "AdminController"

# Disable HTTP Basic authentication since we're using our own session-based auth
MissionControl::Jobs.http_basic_auth_enabled = false
