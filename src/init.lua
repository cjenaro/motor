-- Motor - Coroutine-based HTTP/1.1 Server Engine
-- Part of the Foguete web framework

local socket = require("socket")
local http_parser = require("motor.http_parser")
local connection_manager = require("motor.connection_manager")

local motor = {}

-- Package version
motor.VERSION = "0.0.1"

-- Default server configuration
local DEFAULT_CONFIG = {
    host = "127.0.0.1",
    port = 8080,
    backlog = 128,
    keep_alive_timeout = 30,
    max_request_size = 1024 * 1024, -- 1MB
    socket_timeout = 1.0
}

-- Main server function
function motor.serve(opts, handler)
    if type(opts) == "function" then
        handler = opts
        opts = {}
    end
    
    -- Merge with defaults
    local config = {}
    for k, v in pairs(DEFAULT_CONFIG) do
        config[k] = opts[k] or v
    end
    
    -- Validate handler
    if type(handler) ~= "function" then
        error("Handler must be a function")
    end
    
    print(string.format("🚀 Motor starting on %s:%d", config.host, config.port))
    
    -- Create server socket
    local server = socket.tcp()
    server:settimeout(0) -- Non-blocking
    
    -- Bind and listen
    local ok, err = server:bind(config.host, config.port)
    if not ok then
        error("Failed to bind to " .. config.host .. ":" .. config.port .. ": " .. err)
    end
    
    ok, err = server:listen(config.backlog)
    if not ok then
        error("Failed to listen: " .. err)
    end
    
    -- Connection manager for keep-alive
    local conn_mgr = connection_manager.new(config)
    
    -- Main server loop
    while true do
        -- Use select to wait for activity (non-blocking with timeout)
        local ready_sockets, _, err = socket.select({server}, {}, 0.1) -- 100ms timeout
        
        if ready_sockets and #ready_sockets > 0 then
            -- Accept new connections
            local client = server:accept()
            if client then
                -- Handle connection in coroutine
                local co = coroutine.create(function()
                    motor._handle_connection(client, handler, config, conn_mgr)
                end)
                
                local ok, err = coroutine.resume(co)
                if not ok then
                    print("Error in connection handler: " .. tostring(err))
                end
            end
        end
        
        -- Process existing connections
        conn_mgr:process_connections(handler)
    end
end

-- Handle individual connection
function motor._handle_connection(client, handler, config, conn_mgr)
    client:settimeout(config.socket_timeout)
    
    local connection = {
        socket = client,
        keep_alive = false,
        last_activity = os.time()
    }
    
    while true do
        -- Read HTTP request
        local request_data, err = motor._read_request(client, config)
        if not request_data then
            if err ~= "timeout" then
                print("Error reading request: " .. tostring(err))
            end
            break
        end
        
        -- Parse HTTP request
        local request, parse_err = http_parser.parse_request(request_data)
        if not request then
            motor._send_error_response(client, 400, "Bad Request: " .. tostring(parse_err))
            break
        end
        
        connection.last_activity = os.time()
        
        -- Process request with handler
        local response = motor._safe_handler_call(handler, request)
        
        -- Send response
        local send_ok, send_err = motor._send_response(client, response, request)
        if not send_ok then
            print("Error sending response: " .. tostring(send_err))
            break
        end
        
        -- Check for keep-alive
        local connection_header = request.headers["connection"] or ""
        local should_keep_alive = string.lower(connection_header) == "keep-alive"
        
        if not should_keep_alive or response.close_connection then
            break
        end
        
        connection.keep_alive = true
    end
    
    -- Clean up connection
    client:close()
    conn_mgr:remove_connection(connection)
end

-- Safely call the request handler
function motor._safe_handler_call(handler, request)
    local ok, response = pcall(handler, request)
    
    if not ok then
        print("Handler error: " .. tostring(response))
        return {
            status = 500,
            headers = { ["Content-Type"] = "text/plain" },
            body = "Internal Server Error"
        }
    end
    
    -- Validate response format
    if type(response) ~= "table" then
        return {
            status = 500,
            headers = { ["Content-Type"] = "text/plain" },
            body = "Handler must return a table"
        }
    end
    
    -- Set defaults
    response.status = response.status or 200
    response.headers = response.headers or {}
    response.body = response.body or ""
    
    return response
end

-- Read complete HTTP request from socket
function motor._read_request(client, config)
    local request_data = ""
    local content_length = 0
    local headers_complete = false
    
    while true do
        local chunk, err = client:receive("*l") -- Read line
        if not chunk then
            return nil, err
        end
        
        request_data = request_data .. chunk .. "\r\n"
        
        -- Check for end of headers
        if chunk == "" then
            headers_complete = true
            break
        end
        
        -- Extract content-length if present
        local cl_match = string.match(string.lower(chunk), "content%-length:%s*(%d+)")
        if cl_match then
            content_length = tonumber(cl_match)
        end
        
        -- Prevent request size attacks
        if #request_data > config.max_request_size then
            return nil, "Request too large"
        end
    end
    
    -- Read request body if present
    if content_length > 0 then
        if content_length > config.max_request_size then
            return nil, "Request body too large"
        end
        
        local body, err = client:receive(content_length)
        if not body then
            return nil, err
        end
        
        request_data = request_data .. body
    end
    
    return request_data
end

-- Send HTTP response
function motor._send_response(client, response, request)
    -- Build status line
    local status_line = string.format("HTTP/1.1 %d %s\r\n", 
        response.status, motor._get_status_text(response.status))
    
    -- Build headers
    local headers_str = ""
    local body = response.body or ""
    
    -- Set content-length if not present
    if not response.headers["Content-Length"] and not response.headers["content-length"] then
        response.headers["Content-Length"] = tostring(#body)
    end
    
    -- Set default content-type
    if not response.headers["Content-Type"] and not response.headers["content-type"] then
        response.headers["Content-Type"] = "text/html; charset=utf-8"
    end
    
    -- Serialize headers
    for name, value in pairs(response.headers) do
        headers_str = headers_str .. string.format("%s: %s\r\n", name, value)
    end
    
    -- Complete response
    local full_response = status_line .. headers_str .. "\r\n" .. body
    
    -- Send response
    local bytes_sent, err = client:send(full_response)
    if not bytes_sent then
        return false, err
    end
    
    return true
end

-- Send error response
function motor._send_error_response(client, status, message)
    local response = {
        status = status,
        headers = { ["Content-Type"] = "text/plain" },
        body = message
    }
    
    motor._send_response(client, response, {})
end

-- Get HTTP status text
function motor._get_status_text(status)
    local status_texts = {
        [200] = "OK",
        [201] = "Created",
        [204] = "No Content",
        [301] = "Moved Permanently",
        [302] = "Found",
        [304] = "Not Modified",
        [400] = "Bad Request",
        [401] = "Unauthorized",
        [403] = "Forbidden",
        [404] = "Not Found",
        [405] = "Method Not Allowed",
        [500] = "Internal Server Error",
        [502] = "Bad Gateway",
        [503] = "Service Unavailable"
    }
    
    return status_texts[status] or "Unknown"
end

return motor 