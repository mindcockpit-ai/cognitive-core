# SSRF Elimination: Config Registry Proxy Pattern

## Problem

Server-side proxies that accept user-controlled URLs are inherently SSRF-prone.
Even with allowlists, SonarCloud's S5144 (SSRF) rule correctly flags any path
where user input reaches an HTTP client.

Common vulnerable pattern:

```java
// VULNERABLE: user controls the URL, allowlist can be bypassed
@GetMapping("/proxy")
public ResponseEntity<String> proxy(@RequestParam String url) {
    if (!ALLOWED_HOSTS.contains(URI.create(url).getHost())) {
        return ResponseEntity.badRequest().build();
    }
    return restClient.get().uri(url).retrieve().toEntity(String.class);
}
```

Allowlist bypasses include:
- DNS rebinding (`formular.internal.evil.com` resolves to `169.254.169.254`)
- Open redirects on allowed hosts
- URL parser differentials (`http://allowed.com@evil.com`)

## Solution: Config Registry Proxy

Replace user-controlled URLs with server-side key-to-URL lookup:

```java
// SAFE: user provides a type key, URL resolved entirely from config
@GetMapping("/proxy/form")
public ResponseEntity<String> proxyForm(@RequestParam String type) {
    // Validate key format (alphanumeric only, max 20 chars)
    if (!FORM_TYPE_PATTERN.matcher(type).matches()) {
        return ResponseEntity.badRequest().body(problemDetail("invalid type format"));
    }

    // Lookup URL from application.yml config — no user input in URL
    String url = properties.getFormUrls().get(type);
    if (null == url) {
        return ResponseEntity.notFound().build();
    }

    // RestClient fetches from config-defined URL only
    return restClient.get()
        .uri(URI.create(url))
        .retrieve()
        .toEntity(String.class);
}
```

Configuration:

```yaml
netsave:
  form-urls:
    meldeantrag: "https://formular.amt.de/meldeantrag.html"
    anmeldung: "https://formular.amt.de/anmeldung.html"
```

## Why This Works

- **No taint path**: user input (`type`) never reaches the HTTP client URI
- **SonarCloud S5144 eliminated structurally**: taint analysis confirms no flow from request parameter to `RestClient.uri()`
- **Key validation**: regex `^\w{1,20}$` prevents injection into the lookup itself
- **Redirect following disabled**: prevents 302-based SSRF even if config URL is misconfigured

## Additional Hardening

```java
// Disable redirects — prevents 302 to internal IPs
SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory() {
    @Override
    protected void prepareConnection(HttpURLConnection connection, String httpMethod) throws IOException {
        super.prepareConnection(connection, httpMethod);
        connection.setInstanceFollowRedirects(false);
    }
};
factory.setConnectTimeout(Duration.ofSeconds(5));
factory.setReadTimeout(Duration.ofSeconds(10));

RestClient restClient = RestClient.builder(factory).build();
```

## When to Use

- Any server-side proxy that fetches external resources on behalf of the client
- Form server proxies (CORS bypass for cross-origin form HTML)
- PDF/document generation from external templates
- Webhook forwarding where the destination is known at deploy time

## When NOT to Use

- User-initiated arbitrary URL fetching (e.g., link previews) — use a dedicated service with network-level isolation instead
- APIs where the URL space is unbounded — consider an allowlist with DNS pinning

## Verification

After applying, run SonarCloud analysis and confirm:
- S5144 (SSRF) no longer flagged
- Security hotspot count drops (hotspot review should show "Safe")

## Origin

Discovered during NetSaveHTML CAI-31 (April 2026). Original proxy accepted
`?url={user-controlled}` with host allowlist — SonarCloud correctly flagged S5144.
Refactored to `?type=meldeantrag` → config map lookup. Zero security findings after change.
