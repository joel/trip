# MCP Server Edge Cases

The MCP server (`POST /mcp`) is a first-class feature — test it with the same rigor as the web UI. The server is stateless (no session/handshake needed). Use `tools/call` with `params.name` and `params.arguments`.

## MCP Connection

```bash
MCP_KEY=$(grep MCP_API_KEY .env.development | cut -d= -f2)
MCP_URL="https://catalyst.workeverywhere.docker/mcp"

# Helper function for MCP calls
mcp_call() {
  curl -s "$MCP_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $MCP_KEY" \
    -d "$1"
}
```

## MCP Edge Cases to Test

**Authentication:**
```bash
# No auth header -- expect 401
curl -s -w "HTTP: %{http_code}" "$MCP_URL" -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":"1","method":"tools/list"}'

# Wrong key -- expect 401
curl -s -w "HTTP: %{http_code}" "$MCP_URL" -H "Content-Type: application/json" \
  -H "Authorization: Bearer wrong-key" \
  -d '{"jsonrpc":"2.0","id":"1","method":"tools/list"}'

# Wrong content type -- expect 415
curl -s -w "HTTP: %{http_code}" "$MCP_URL" -H "Content-Type: text/plain" \
  -H "Authorization: Bearer $MCP_KEY" \
  -d '{"jsonrpc":"2.0","id":"1","method":"tools/list"}'

# Malformed JSON -- expect -32700 parse error
mcp_call 'not-json-at-all'
```

**Tool invocation:**
```bash
# Unknown tool name -- expect error
mcp_call '{"jsonrpc":"2.0","id":"1","method":"tools/call","params":{"name":"nonexistent_tool","arguments":{}}}'

# Wrong JSON-RPC method (common mistake) -- expect "Method not found"
mcp_call '{"jsonrpc":"2.0","id":"1","method":"get_trip_status","params":{}}'

# Missing required arguments
mcp_call '{"jsonrpc":"2.0","id":"1","method":"tools/call","params":{"name":"create_journal_entry","arguments":{}}}'
```

**State guards (test each trip state):**
```bash
# Get all trip IDs
cat > /tmp/qa-trips.rb <<'RUBY'
Trip.all.each { |t| puts "#{t.state.ljust(10)} #{t.id} #{t.name}" }
RUBY
docker exec -i catalyst-app-dev bin/rails runner - < /tmp/qa-trips.rb

# Create entry on writable trip (started) -- expect success
mcp_call '{"jsonrpc":"2.0","id":"1","method":"tools/call","params":{"name":"create_journal_entry","arguments":{"name":"QA Test","entry_date":"2026-03-25","trip_id":"<started-trip-id>"}}}'

# Create entry on finished trip -- expect "not writable"
mcp_call '{"jsonrpc":"2.0","id":"1","method":"tools/call","params":{"name":"create_journal_entry","arguments":{"name":"QA Test","entry_date":"2026-03-25","trip_id":"<finished-trip-id>"}}}'

# Create entry on cancelled trip -- expect "not writable"
# Create entry on archived trip -- expect "not writable"

# Comment on finished trip -- expect success (commentable)
# Comment on cancelled trip -- expect "not commentable"
```

**Image upload edge cases:**
```bash
# Upload with invalid base64
mcp_call '{"jsonrpc":"2.0","id":"1","method":"tools/call","params":{"name":"upload_journal_images","arguments":{"journal_entry_id":"<id>","images":[{"data":"not-valid!!!"}]}}}'
# Expect: "Invalid base64"

# Upload non-image content (HTML disguised as base64)
HTML_B64=$(echo "<html>evil</html>" | base64 -w0)
mcp_call "{\"jsonrpc\":\"2.0\",\"id\":\"1\",\"method\":\"tools/call\",\"params\":{\"name\":\"upload_journal_images\",\"arguments\":{\"journal_entry_id\":\"<id>\",\"images\":[{\"data\":\"$HTML_B64\"}]}}}"
# Expect: "Invalid content type"

# Upload > 5 images -- expect "Too many"
# Upload to nonexistent entry -- expect "not found"

# Upload a REAL image and verify it renders in browser
B64_IMG=$(curl -sL "https://picsum.photos/200/150.jpg" | base64 -w0)
mcp_call "{\"jsonrpc\":\"2.0\",\"id\":\"1\",\"method\":\"tools/call\",\"params\":{\"name\":\"upload_journal_images\",\"arguments\":{\"journal_entry_id\":\"<id>\",\"images\":[{\"data\":\"$B64_IMG\",\"filename\":\"qa_test.jpg\"}]}}}"
# THEN: open the entry in agent-browser and verify the image renders (not broken)
```

**Cross-verify MCP writes in browser:**
Every MCP write operation must be verified in the web UI. If `create_journal_entry` returns success, open that entry in agent-browser and confirm it renders.

## MCP Report Section

Add to the QA report:

```
## MCP Server

| Test | Expected | Actual |
|------|----------|--------|
| tools/list returns 12 tools | 12 | ? |
| Auth: no key | 401 | ? |
| Auth: wrong key | 401 | ? |
| Auth: wrong content-type | 415 | ? |
| Auth: malformed JSON | -32700 | ? |
| get_trip_status (started) | success with trip data | ? |
| create_journal_entry (started) | success, visible in browser | ? |
| create_journal_entry (finished) | "not writable" error | ? |
| create_comment (finished) | success (commentable) | ? |
| create_comment (cancelled) | "not commentable" error | ? |
| upload_journal_images (valid) | success, image renders in browser | ? |
| upload_journal_images (invalid b64) | "Invalid base64" error | ? |
| upload_journal_images (non-image) | "Invalid content type" error | ? |
| upload_journal_images (> 5 images) | "Too many" error | ? |
| Unknown tool name | error response | ? |
| Wrong JSON-RPC method | "Method not found" | ? |
```
