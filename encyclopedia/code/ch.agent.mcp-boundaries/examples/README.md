# Local MCP boundary fixture

This uses the installed MCP Python SDK's in-memory transport, FastMCP server and
ClientSession plus an installed LangGraph StateGraph. It opens no socket and uses
no real Java service, OAuth server, database or model. The authority, identity and
kill switch are controlled fixtures, so the result is a protocol-contract test,
not evidence of deployed authorization or process termination.
