#!/usr/bin/env lua

-- Motor HTTP Server Example
-- Demonstrates basic usage of the Motor engine

local motor = require("motor")

-- Example request handler
local function handle_request(request)
    print(string.format("[%s] %s %s", os.date("%H:%M:%S"), request.method, request.path))
    
    -- Route handling
    if request.path == "/" then
        return {
            status = 200,
            headers = { 
                ["Content-Type"] = "text/html; charset=utf-8"
            },
            body = [[
<!DOCTYPE html>
<html>
<head>
    <title>Motor HTTP Server</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .container { max-width: 600px; margin: 0 auto; }
        .endpoint { background: #f5f5f5; padding: 15px; margin: 10px 0; border-radius: 5px; }
        code { background: #e8e8e8; padding: 2px 5px; border-radius: 3px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Motor HTTP Server</h1>
        <p>Your coroutine-based HTTP/1.1 server is running!</p>
        
        <h2>Available Endpoints:</h2>
        <div class="endpoint">
            <strong>GET /</strong> - This page
        </div>
        <div class="endpoint">
            <strong>GET /hello</strong> - Simple greeting
        </div>
        <div class="endpoint">
            <strong>GET /hello?name=YourName</strong> - Personalized greeting
        </div>
        <div class="endpoint">
            <strong>POST /echo</strong> - Echo request body
        </div>
        <div class="endpoint">
            <strong>GET /json</strong> - JSON response
        </div>
        <div class="endpoint">
            <strong>GET /status</strong> - Server status
        </div>
        
        <h2>Features:</h2>
        <ul>
            <li>✅ HTTP/1.1 Protocol Support</li>
            <li>✅ Keep-Alive Connections</li>
            <li>✅ Query Parameter Parsing</li>
            <li>✅ POST Body Handling</li>
            <li>✅ JSON Responses</li>
            <li>✅ Error Handling</li>
            <li>✅ Coroutine-based Concurrency</li>
        </ul>
        
        <p><em>Part of the Foguete web framework</em></p>
    </div>
</body>
</html>
            ]]
        }
        
    elseif request.path == "/hello" then
        local name = request.query.name or "World"
        return {
            status = 200,
            headers = { 
                ["Content-Type"] = "text/plain; charset=utf-8"
            },
            body = "Hello, " .. name .. "! 👋"
        }
        
    elseif request.path == "/json" then
        return {
            status = 200,
            headers = { 
                ["Content-Type"] = "application/json"
            },
            body = '{"message": "Hello from Motor!", "timestamp": ' .. os.time() .. ', "server": "Motor/1.0"}'
        }
        
    elseif request.path == "/echo" and request.method == "POST" then
        local content_type = request.headers["content-type"] or "text/plain"
        
        return {
            status = 200,
            headers = { 
                ["Content-Type"] = content_type,
                ["X-Original-Method"] = request.method
            },
            body = request.body
        }
        
    elseif request.path == "/status" then
        -- This would normally get stats from connection manager
        local stats = {
            server = "Motor HTTP Server",
            version = "1.0.0",
            uptime = "N/A", -- Would be calculated in real implementation
            memory = "N/A", -- Would use collectgarbage("count") * 1024
            requests_served = "N/A", -- Would track in connection manager
            lua_version = _VERSION
        }
        
        local response_body = "=== Motor Server Status ===\n"
        for key, value in pairs(stats) do
            response_body = response_body .. string.format("%s: %s\n", key, value)
        end
        
        return {
            status = 200,
            headers = { 
                ["Content-Type"] = "text/plain; charset=utf-8"
            },
            body = response_body
        }
        
    else
        -- 404 Not Found
        return {
            status = 404,
            headers = { 
                ["Content-Type"] = "text/html; charset=utf-8"
            },
            body = [[
<!DOCTYPE html>
<html>
<head>
    <title>404 - Not Found</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; margin-top: 100px; }
        .error { color: #e74c3c; }
    </style>
</head>
<body>
    <h1 class="error">404 - Not Found</h1>
    <p>The requested path <code>]] .. request.path .. [[</code> was not found.</p>
    <p><a href="/">← Back to Home</a></p>
</body>
</html>
            ]]
        }
    end
end

-- Start the server
print("Starting Motor HTTP Server example...")
print("Press Ctrl+C to stop the server")

-- Server configuration
local config = {
    host = "127.0.0.1",
    port = 8080,
    keep_alive_timeout = 30,
    max_request_size = 1024 * 1024 -- 1MB
}

-- Start server (this will block)
motor.serve(config, handle_request) 