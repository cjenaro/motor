-- Motor Type Definitions
-- Type annotations for the Motor HTTP server engine

---@meta

---@class MotorConfig
---@field host string Server host address (default: "127.0.0.1")
---@field port integer Server port number (default: 8080)
---@field backlog integer Connection backlog size (default: 128)
---@field keep_alive_timeout integer Keep-alive timeout in seconds (default: 30)
---@field max_request_size integer Maximum request size in bytes (default: 1MB)
---@field socket_timeout number Socket timeout in seconds (default: 1.0)
---@field hot_reload boolean Enable hot reload for development (default: false)
---@field hot_reload_interval number Hot reload check interval in seconds (default: 0.5)
---@field hot_reload_watch_dirs WatchDir[]? Directories to watch for hot reload
---@field hot_reload_app_root string? Application root for hot reload

---@class WatchDir
---@field path string Directory path to watch
---@field module_prefix string Module prefix for watched files

---@class HttpRequest
---@field method string HTTP method (GET, POST, etc.)
---@field path string Request path
---@field query table<string, string> Query parameters
---@field headers table<string, string> HTTP headers (case-insensitive)
---@field body string Request body
---@field data table Parsed body data (form data, JSON, etc.)
---@field version string HTTP version

---@class HttpResponse
---@field status integer HTTP status code
---@field headers table<string, string> Response headers
---@field body string Response body
---@field close_connection boolean? Whether to close connection after response

---@class Connection
---@field id string? Unique connection identifier
---@field socket userdata TCP socket object
---@field keep_alive boolean Whether connection supports keep-alive
---@field last_activity integer Timestamp of last activity
---@field created_at integer? Timestamp when connection was created

---@class ConnectionManager
---@field connections table<string, Connection> Active connections
---@field config MotorConfig Configuration object
---@field last_cleanup integer Timestamp of last cleanup
---@field created_at integer? Timestamp when manager was created

---@alias RequestHandler fun(request: HttpRequest): HttpResponse
---@alias SocketErrorType "timeout" | "closed" | string

---@class ConnectionStats
---@field total_connections integer Total number of active connections
---@field keep_alive_connections integer Number of keep-alive connections
---@field manager_uptime integer Manager uptime in seconds

