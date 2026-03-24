# Security Review -- feature/phase-10-mcp-image-attachment

**Date:** 2026-03-24
**Reviewer:** Claude (adversarial security pass)
**Branch:** `feature/phase-10-mcp-image-attachment`
**Diff scope:** `git diff main...HEAD` (12 files, +866/-18 lines)

## Summary

This branch adds a new MCP tool (`AddJournalImages`) and supporting action (`JournalEntries::AttachImages`) that downloads images from user-supplied HTTPS URLs and attaches them to journal entries via Active Storage. The implementation includes SSRF protection via DNS resolution against a blocklist, content-type validation, file-size limits, and trip-state guards. The overall design is solid, but there are two findings that should be addressed before merge and one that should be consciously accepted.

---

## Critical (must fix before merge)

### C1: TOCTOU DNS rebinding bypasses SSRF protection

**File:** `app/actions/journal_entries/attach_images.rb:63-73` (validate_host!) and `:111-124` (download)

**Explanation:** The SSRF protection resolves the hostname to an IP via `Resolv.getaddress` and checks that IP against the blocklist. Then, separately, `URI.open` makes its own DNS resolution via `Net::HTTP` / `Socket` to actually connect. Between these two lookups there is a time-of-check-time-of-use (TOCTOU) window. An attacker controlling a DNS server can return a public IP for the first lookup (passing validation) and a private/internal IP for the second lookup (reaching internal services). This is known as a DNS rebinding attack.

Additionally, `Resolv.getaddress` returns only a single address. A hostname with multiple A/AAAA records (one public, one private) could pass the check on the public record while `Net::HTTP` connects to the private one.

**Fix:** Replace the two-step resolve-then-open approach with a single-step approach that resolves the IP once, validates it, and then connects to that specific IP. The idiomatic Ruby approach is to use `Net::HTTP` directly with the resolved IP as the connection address and set the `Host` header manually. Alternatively, pass `redirect: false` to `URI.open` (to prevent redirect-based bypasses) and use the resolved IP in the URL itself, though this is more complex with HTTPS/SNI.

Recommended pattern:

```ruby
def download(url)
  uri = URI.parse(url)
  ip = resolve_and_validate!(uri)  # Already done in validate_urls

  http = Net::HTTP.new(ip, uri.port)
  http.use_ssl = true
  http.open_timeout = OPEN_TIMEOUT
  http.read_timeout = READ_TIMEOUT

  request = Net::HTTP::Get.new(uri.request_uri)
  request["Host"] = uri.host

  response = http.request(request)
  # Handle response, check for redirects manually
  # (reject redirects or re-validate the redirect target)
end
```

### C2: HTTP redirects bypass SSRF protection entirely

**File:** `app/actions/journal_entries/attach_images.rb:111-124` (download)

**Explanation:** `URI.open` follows up to 64 HTTP redirects by default (Ruby 4.0 open-uri). The SSRF validation only checks the original URL's hostname. An attacker can host an HTTPS endpoint at a public IP that returns a 302 redirect to `https://169.254.169.254/latest/meta-data/` (cloud metadata) or any internal HTTPS service. The redirect target is never validated against the blocklist.

Note: HTTPS-to-HTTP redirects are blocked by Ruby's `OpenURI.redirectable?`, so the cloud metadata endpoint (typically HTTP) is partially mitigated. However, any internal service accessible over HTTPS remains reachable.

**Fix:** Either:
1. Disable redirects: `URI.open(url, redirect: false, ...)` and return a failure if a redirect is received, OR
2. Use `Net::HTTP` directly (as suggested in C1) and manually validate each redirect target against the blocklist before following it.

Option 1 is simpler and recommended unless there is a product requirement to follow redirects for image CDNs. Most image CDNs (Cloudflare, CloudFront, imgix) serve images directly without redirects on the canonical URL.

---

## Warning (should fix or consciously accept)

### W1: Incomplete IP blocklist -- missing reserved ranges

**File:** `app/actions/journal_entries/attach_images.rb:18-26` (BLOCKED_NETWORKS)

**Explanation:** The blocklist covers the most common private/link-local ranges but misses several reserved ranges that should also be blocked:

| Range | Risk | Status |
|---|---|---|
| `0.0.0.0/8` | Alias for localhost on some OS kernels | ALLOWED |
| `100.64.0.0/10` | Carrier-grade NAT (RFC 6598), used by cloud VPCs (e.g., AWS VPC internal) | ALLOWED |
| `198.18.0.0/15` | Benchmarking (RFC 2544), sometimes used internally | ALLOWED |
| `240.0.0.0/4` | Reserved for future use, should not be routable | ALLOWED |
| `::ffff:127.0.0.1` | IPv4-mapped IPv6 addresses bypass IPv4 blocklist checks | ALLOWED |
| `::ffff:169.254.169.254` | IPv4-mapped IPv6 for cloud metadata | ALLOWED |

The IPv4-mapped IPv6 addresses (`::ffff:x.x.x.x`) are particularly concerning because `IPAddr.new("::ffff:127.0.0.1")` is NOT included in `IPAddr.new("127.0.0.0/8")` -- they are in different address families.

**Fix:** Add the missing ranges and normalize IPv4-mapped IPv6 to IPv4 before checking:

```ruby
BLOCKED_NETWORKS = [
  IPAddr.new("0.0.0.0/8"),        # "this" network
  IPAddr.new("10.0.0.0/8"),
  IPAddr.new("100.64.0.0/10"),    # carrier-grade NAT
  IPAddr.new("127.0.0.0/8"),
  IPAddr.new("169.254.0.0/16"),
  IPAddr.new("172.16.0.0/12"),
  IPAddr.new("192.168.0.0/16"),
  IPAddr.new("198.18.0.0/15"),    # benchmarking
  IPAddr.new("240.0.0.0/4"),      # reserved
  IPAddr.new("::1/128"),
  IPAddr.new("fc00::/7"),
  IPAddr.new("fe80::/10")         # IPv6 link-local
].freeze

def validate_host!(uri)
  ip = Resolv.getaddress(uri.host)
  addr = IPAddr.new(ip)
  # Normalize IPv4-mapped IPv6 to IPv4 for blocklist check
  addr = addr.native if addr.ipv4_mapped?
  return unless BLOCKED_NETWORKS.any? { |net| net.include?(addr) }
  # ...
end
```

### W2: No model-level Active Storage validation

**File:** `app/models/journal_entry.rb:8`

**Explanation:** The `JournalEntry` model declares `has_many_attached :images` with no content-type or file-size validation at the model level. The `AttachImages` action validates content type and size before attaching, but any other code path that calls `journal_entry.images.attach(...)` directly (e.g., a future controller action, Rails console, or another action) would bypass these checks entirely.

**Fix:** Add model-level validations as a defense-in-depth measure:

```ruby
# app/models/journal_entry.rb
validates :images,
  content_type: %w[image/jpeg image/png image/webp image/gif],
  size: { less_than: 10.megabytes }
```

This requires the `activestorage-validator` gem or Rails 7.1+ built-in validations. If neither is available, a custom validator would work. This is defense-in-depth -- the action-level checks are the primary gate.

### W3: Content-type validation relies on server-reported Content-Type header

**File:** `app/actions/journal_entries/attach_images.rb:126-133`

**Explanation:** `io.content_type` returns the `Content-Type` header from the HTTP response, which is set by the remote server. A malicious server could set `Content-Type: image/jpeg` while serving an HTML file containing JavaScript (stored XSS if served inline). The file's actual content is not inspected (no magic-byte / file-signature validation).

**Mitigation already in place:** Active Storage serves attachments with `Content-Disposition: attachment` by default, which prevents inline rendering in the browser. Additionally, `ProcessJournalImagesJob` calls `image.variant(resize_to_limit: ...)` via `image_processing`/vips, which would fail on non-image files, providing a post-hoc check.

**Residual risk:** Low, given the existing mitigations. For additional hardening, consider validating magic bytes (JPEG starts with `FF D8 FF`, PNG with `89 50 4E 47`, etc.) before attaching.

---

## Informational (no action required)

### I1: MCP authentication and authorization are correctly applied

The MCP endpoint requires a valid `MCP_API_KEY` (checked with `secure_compare`). The `AddJournalImages` tool calls `require_writable!(entry.trip)` to enforce trip-state guards. `JournalEntry.find(journal_entry_id)` uses UUIDs (non-enumerable). The tool follows the same authorization pattern as all other MCP tools. No issues found.

### I2: Error messages do not leak internal state

Error messages returned by the action and tool are descriptive but do not expose internal paths, stack traces, or infrastructure details. The "Blocked host (internal network)" message is appropriate -- it tells the caller the host is blocked without revealing which specific internal network matched.

### I3: No new `unsafe_raw` or `html_safe` usage

The diff introduces no new view code and no usage of `unsafe_raw`, `html_safe`, or `raw`. The changes to skill `.md` files are documentation only.

### I4: No secrets, tokens, or credentials in the diff

No `.env` files, credentials, or hardcoded secrets are present in the diff. The `MCP_API_KEY` is correctly loaded from the environment.

### I5: No new gems or dependencies added

The `Gemfile` and `Gemfile.lock` are unchanged. No new dependencies to review.

### I6: No new routes added

The image attachment feature is exposed exclusively through the existing MCP endpoint (`POST /mcp`). No new HTTP routes were added.

### I7: Test coverage is thorough

The spec suite covers:
- Valid attachment flow
- Empty/non-array URL rejection
- Non-HTTPS rejection
- URL count limits
- Image count limits (per entry)
- Malformed URL rejection
- Timeout, HTTP error, and connection refused handling
- SSRF: localhost, private networks, cloud metadata, unresolvable hosts
- Content-type rejection
- File-size rejection
- Trip-state guard (non-writable trip)
- Nonexistent journal entry

### I8: Download-then-attach pattern prevents partial attachment

The `download_all` method downloads all images before calling `attach_all`. If any download fails, no images are attached. This is correct behavior and prevents partial/inconsistent state.

---

## Not applicable

| Category | Reason |
|---|---|
| **Authentication (new routes)** | No new routes added; MCP endpoint authentication unchanged |
| **Strong parameters** | No controller actions added; MCP tool uses explicit named parameters |
| **Invitation/token flows** | Not touched by this diff |
| **Raw SQL** | No SQL in the diff |
| **Mass assignment** | No new model attributes exposed |

---

## Severity Summary

| Severity | Count | Action Required |
|---|---|---|
| Critical | 2 | Must fix before merge |
| Warning | 3 | Should fix or consciously accept |
| Informational | 8 | No action required |

The two critical findings (C1 + C2) are closely related and can be addressed together by switching from `URI.open` to `Net::HTTP` with the pre-resolved IP address and disabling automatic redirect following. This is the standard approach for SSRF-safe URL fetching in Ruby.
