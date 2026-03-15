require "ipaddr"
require "resolv"
require "uri"

module UrlSafety
  SAFE_SCHEMES = %w[http https].freeze
  PRIVATE_IP_RANGES = [
    IPAddr.new("127.0.0.0/8"),
    IPAddr.new("10.0.0.0/8"),
    IPAddr.new("172.16.0.0/12"),
    IPAddr.new("192.168.0.0/16"),
    IPAddr.new("169.254.0.0/16"),
    IPAddr.new("::1/128"),
    IPAddr.new("fc00::/7"),
    IPAddr.new("fe80::/10")
  ].freeze

  module_function

  def safe_uri_for(raw_url)
    return if raw_url.blank?

    uri = URI.parse(raw_url.to_s.strip)
    return unless SAFE_SCHEMES.include?(uri.scheme)

    host = uri.hostname
    return if host.blank? || unsafe_host?(host)

    uri
  rescue URI::InvalidURIError
    nil
  end

  def unsafe_host?(host)
    return true if host.casecmp("localhost").zero? || host.downcase.end_with?(".local")

    # First check if the host is already an IP address literal
    begin
      ip = IPAddr.new(host)
      return PRIVATE_IP_RANGES.any? { |range| range.include?(ip) }
    rescue IPAddr::InvalidAddressError
      # Not an IP literal — it's a domain name, resolve it below
    rescue ArgumentError
      return true # Malformed input
    end

    # Resolve the domain name and check all resulting IPs against private ranges
    # This prevents DNS rebinding attacks where a domain resolves to a private IP
    begin
      addresses = Resolv.getaddresses(host)
      return true if addresses.empty?

      addresses.any? { |addr|
        ip = IPAddr.new(addr)
        PRIVATE_IP_RANGES.any? { |range| range.include?(ip) }
      }
    rescue Resolv::ResolvError
      true # Cannot resolve — treat as unsafe
    rescue IPAddr::InvalidAddressError
      true
    end
  end
end
