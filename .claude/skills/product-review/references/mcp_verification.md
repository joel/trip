# MCP Server Verification

The app exposes 12 MCP tools at `POST /mcp`. The MCP server is stateless — every request is independent, no initialize handshake required. Test it alongside the web UI.

## MCP Connection

```bash
# Set the API key from .env.development
MCP_KEY=$(grep MCP_API_KEY .env.development | cut -d= -f2)

# Quick health check -- list all tools
curl -s https://catalyst.workeverywhere.docker/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MCP_KEY" \
  -d '{"jsonrpc":"2.0","id":"1","method":"tools/list"}' \
  | python3 -c "import json,sys; tools=json.load(sys.stdin)['result']['tools']; print(f'{len(tools)} tools'); [print(f'  - {t[\"name\"]}') for t in tools]"
```

Expected: 12 tools listed.

## MCP Tool Tests

Test each category of tool against the live Docker app:

```bash
# 1. Read operation -- get trip status (auto-resolves to started trip)
curl -s https://catalyst.workeverywhere.docker/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MCP_KEY" \
  -d '{"jsonrpc":"2.0","id":"2","method":"tools/call","params":{"name":"get_trip_status","arguments":{}}}' \
  | python3 -m json.tool

# 2. Read operation -- list journal entries
curl -s https://catalyst.workeverywhere.docker/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MCP_KEY" \
  -d '{"jsonrpc":"2.0","id":"3","method":"tools/call","params":{"name":"list_journal_entries","arguments":{"limit":3}}}' \
  | python3 -m json.tool

# 3. Write operation -- create a journal entry on the started trip
curl -s https://catalyst.workeverywhere.docker/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MCP_KEY" \
  -d '{"jsonrpc":"2.0","id":"4","method":"tools/call","params":{"name":"create_journal_entry","arguments":{"name":"MCP Test Entry","entry_date":"2026-03-25","body":"<p>Created by product review.</p>","location_name":"Docker"}}}' \
  | python3 -m json.tool

# 4. Upload image -- use a real image (not a stub!)
B64_IMG=$(curl -sL "https://picsum.photos/200/150.jpg" | base64 -w0)
ENTRY_ID=<uuid-from-step-3>
curl -s https://catalyst.workeverywhere.docker/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MCP_KEY" \
  -d "{\"jsonrpc\":\"2.0\",\"id\":\"5\",\"method\":\"tools/call\",\"params\":{\"name\":\"upload_journal_images\",\"arguments\":{\"journal_entry_id\":\"$ENTRY_ID\",\"images\":[{\"data\":\"$B64_IMG\",\"filename\":\"review_test.jpg\"}]}}}" \
  | python3 -m json.tool

# 5. Verify the uploaded image renders in the browser
agent-browser open "https://catalyst.workeverywhere.docker/trips/$TRIP_ID/journal_entries/$ENTRY_ID" && agent-browser wait --load networkidle
agent-browser eval "document.querySelectorAll('img[alt]').length"  # Count rendered images
agent-browser screenshot /tmp/rt-mcp-entry.png

# 6. State guard -- reject write on finished trip
FINISHED_ENTRY_ID=$(docker exec catalyst-app-dev bin/rails runner "puts Trip.find_by(state: :finished).journal_entries.first.id" 2>&1 | tail -1)
curl -s https://catalyst.workeverywhere.docker/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MCP_KEY" \
  -d "{\"jsonrpc\":\"2.0\",\"id\":\"6\",\"method\":\"tools/call\",\"params\":{\"name\":\"upload_journal_images\",\"arguments\":{\"journal_entry_id\":\"$FINISHED_ENTRY_ID\",\"images\":[{\"data\":\"$B64_IMG\"}]}}}" \
  | python3 -m json.tool
# Expected: isError: true, "not writable"

# 7. Auth guard -- reject without API key
curl -s -w "\nHTTP: %{http_code}\n" https://catalyst.workeverywhere.docker/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":"7","method":"tools/list"}'
# Expected: HTTP 401
```

## MCP Verification Criteria

- All 12 tools listed
- Read tools return correct data matching seed data
- Write tools create records visible in the web UI
- Uploaded images render in the browser (not broken/stub)
- State guards reject writes on non-writable trips
- Auth rejects requests without valid API key
- Invalid tool name returns JSON-RPC "Method not found"
