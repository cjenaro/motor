-- Connection Manager for Motor
-- Handles keep-alive connections and connection pooling

local connection_manager = {}

-- Create a new connection manager
function connection_manager.new(config)
    local manager = {
        connections = {}, -- Active connections
        config = config or {},
        last_cleanup = os.time()
    }
    
    setmetatable(manager, { __index = connection_manager })
    return manager
end

-- Add a connection to management
function connection_manager:add_connection(connection)
    if not connection or not connection.socket then
        return false
    end
    
    connection.id = self:_generate_connection_id()
    connection.created_at = os.time()
    connection.last_activity = os.time()
    
    self.connections[connection.id] = connection
    return connection.id
end

-- Remove a connection
function connection_manager:remove_connection(connection)
    if not connection then
        return
    end
    
    local id = connection.id
    if id and self.connections[id] then
        -- Close socket if still open
        if self.connections[id].socket then
            local ok = pcall(function()
                self.connections[id].socket:close()
            end)
            if not ok then
                -- Socket already closed or error, ignore
            end
        end
        
        self.connections[id] = nil
    end
end

-- Process all active connections
function connection_manager:process_connections(handler)
    local current_time = os.time()
    local connections_to_remove = {}
    
    -- Check each connection
    for id, connection in pairs(self.connections) do
        if self:_should_close_connection(connection, current_time) then
            table.insert(connections_to_remove, connection)
        elseif connection.keep_alive and connection.socket then
            -- Try to read more data from keep-alive connection
            self:_process_keep_alive_connection(connection, handler)
        end
    end
    
    -- Remove timed out connections
    for _, connection in ipairs(connections_to_remove) do
        self:remove_connection(connection)
    end
    
    -- Periodic cleanup
    if current_time - self.last_cleanup > 30 then
        self:_cleanup_stale_connections()
        self.last_cleanup = current_time
    end
end

-- Check if a connection should be closed
function connection_manager:_should_close_connection(connection, current_time)
    if not connection.socket then
        return true
    end
    
    -- Check timeout
    local timeout = self.config.keep_alive_timeout or 30
    if current_time - connection.last_activity > timeout then
        return true
    end
    
    -- Check if socket is still valid
    local socket = connection.socket
    socket:settimeout(0) -- Non-blocking check
    
    local data, err = socket:receive(0)
    if err == "closed" then
        return true
    end
    
    return false
end

-- Process a keep-alive connection for new requests
function connection_manager:_process_keep_alive_connection(connection, handler)
    if not connection.socket or not handler then
        return
    end
    
    local socket = connection.socket
    socket:settimeout(0) -- Non-blocking
    
    -- Try to read request line to see if new request is available
    local line, err = socket:receive("*l")
    if not line then
        if err ~= "timeout" then
            -- Connection closed or error
            self:remove_connection(connection)
        end
        return
    end
    
    -- We have a new request on keep-alive connection
    -- Put the line back by creating a new coroutine to handle it
    local co = coroutine.create(function()
        self:_handle_keep_alive_request(connection, line, handler)
    end)
    
    local ok, err = coroutine.resume(co)
    if not ok then
        print("Error handling keep-alive request: " .. tostring(err))
        self:remove_connection(connection)
    end
end

-- Handle a request on a keep-alive connection
function connection_manager:_handle_keep_alive_request(connection, first_line, handler)
    local socket = connection.socket
    local request_data = first_line .. "\r\n"
    
    -- Read rest of headers
    while true do
        local line, err = socket:receive("*l")
        if not line then
            if err ~= "timeout" then
                self:remove_connection(connection)
            end
            return
        end
        
        request_data = request_data .. line .. "\r\n"
        
        if line == "" then
            break -- End of headers
        end
    end
    
    -- Check for request body
    local content_length = 0
    local cl_match = string.match(string.lower(request_data), "content%-length:%s*(%d+)")
    if cl_match then
        content_length = tonumber(cl_match)
    end
    
    -- Read body if present
    if content_length > 0 then
        local max_size = self.config.max_request_size or (1024 * 1024)
        if content_length > max_size then
            self:_send_error_response(socket, 413, "Request Entity Too Large")
            self:remove_connection(connection)
            return
        end
        
        local body, err = socket:receive(content_length)
        if not body then
            self:remove_connection(connection)
            return
        end
        
        request_data = request_data .. body
    end
    
    -- Parse and handle the request
    local http_parser = require("motor.http_parser")
    local request, parse_err = http_parser.parse_request(request_data)
    
    if not request then
        self:_send_error_response(socket, 400, "Bad Request: " .. tostring(parse_err))
        self:remove_connection(connection)
        return
    end
    
    -- Update connection activity
    connection.last_activity = os.time()
    
    -- Call handler
    local response = self:_safe_handler_call(handler, request)
    
    -- Send response
    local send_ok = self:_send_response(socket, response)
    if not send_ok then
        self:remove_connection(connection)
        return
    end
    
    -- Check if connection should remain open
    local connection_header = request.headers["connection"] or ""
    local should_keep_alive = string.lower(connection_header) == "keep-alive"
    
    if not should_keep_alive or response.close_connection then
        self:remove_connection(connection)
    end
end

-- Generate unique connection ID
function connection_manager:_generate_connection_id()
    return string.format("conn_%d_%d", os.time(), math.random(10000, 99999))
end

-- Clean up stale connections
function connection_manager:_cleanup_stale_connections()
    local current_time = os.time()
    local stale_connections = {}
    
    for id, connection in pairs(self.connections) do
        if self:_should_close_connection(connection, current_time) then
            table.insert(stale_connections, connection)
        end
    end
    
    for _, connection in ipairs(stale_connections) do
        self:remove_connection(connection)
    end
    
    -- Log cleanup stats
    if #stale_connections > 0 then
        print(string.format("Cleaned up %d stale connections", #stale_connections))
    end
end

-- Safely call handler with error handling
function connection_manager:_safe_handler_call(handler, request)
    local ok, response = pcall(handler, request)
    
    if not ok then
        print("Handler error: " .. tostring(response))
        return {
            status = 500,
            headers = { ["Content-Type"] = "text/plain" },
            body = "Internal Server Error"
        }
    end
    
    -- Validate response
    if type(response) ~= "table" then
        return {
            status = 500,
            headers = { ["Content-Type"] = "text/plain" },
            body = "Handler must return a table"
        }
    end
    
    response.status = response.status or 200
    response.headers = response.headers or {}
    response.body = response.body or ""
    
    return response
end

-- Send HTTP response
function connection_manager:_send_response(socket, response)
    -- Build status line
    local status_texts = {
        [200] = "OK", [400] = "Bad Request", [404] = "Not Found",
        [413] = "Request Entity Too Large", [500] = "Internal Server Error"
    }
    
    local status_text = status_texts[response.status] or "Unknown"
    local status_line = string.format("HTTP/1.1 %d %s\r\n", response.status, status_text)
    
    -- Build headers
    local headers_str = ""
    local body = response.body or ""
    
    -- Set content-length
    if not response.headers["Content-Length"] and not response.headers["content-length"] then
        response.headers["Content-Length"] = tostring(#body)
    end
    
    -- Set default content-type
    if not response.headers["Content-Type"] and not response.headers["content-type"] then
        response.headers["Content-Type"] = "text/html; charset=utf-8"
    end
    
    for name, value in pairs(response.headers) do
        headers_str = headers_str .. string.format("%s: %s\r\n", name, value)
    end
    
    -- Send complete response
    local full_response = status_line .. headers_str .. "\r\n" .. body
    local bytes_sent, err = socket:send(full_response)
    
    return bytes_sent ~= nil
end

-- Send error response
function connection_manager:_send_error_response(socket, status, message)
    local response = {
        status = status,
        headers = { ["Content-Type"] = "text/plain" },
        body = message
    }
    
    return self:_send_response(socket, response)
end

-- Get connection statistics
function connection_manager:get_stats()
    local total_connections = 0
    local keep_alive_connections = 0
    local current_time = os.time()
    
    for _, connection in pairs(self.connections) do
        total_connections = total_connections + 1
        if connection.keep_alive then
            keep_alive_connections = keep_alive_connections + 1
        end
    end
    
    return {
        total_connections = total_connections,
        keep_alive_connections = keep_alive_connections,
        manager_uptime = current_time - (self.created_at or current_time)
    }
end

return connection_manager 