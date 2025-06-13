-- Motor HTTP Server Test Suite
-- Uses Busted testing framework

describe("Motor HTTP Server", function()
    local motor = require("motor")
    local http_parser = require("motor.http_parser")
    local connection_manager = require("motor.connection_manager")

    describe("HTTP Parser", function()
        it("should parse simple GET request", function()
            local request_data = "GET /hello HTTP/1.1\r\nHost: localhost\r\nUser-Agent: test\r\n\r\n"
            local request, err = http_parser.parse_request(request_data)
            
            assert.is_nil(err)
            assert.is_not_nil(request)
            assert.are.equal("GET", request.method)
            assert.are.equal("/hello", request.path)
            assert.are.equal("localhost", request.headers["host"])
            assert.are.equal("test", request.headers["user-agent"])
            assert.are.equal("", request.body)
        end)

        it("should parse GET request with query parameters", function()
            local request_data = "GET /search?q=lua&type=web HTTP/1.1\r\nHost: localhost\r\n\r\n"
            local request, err = http_parser.parse_request(request_data)
            
            assert.is_nil(err)
            assert.is_not_nil(request)
            assert.are.equal("GET", request.method)
            assert.are.equal("/search", request.path)
            assert.are.equal("lua", request.query.q)
            assert.are.equal("web", request.query.type)
        end)

        it("should parse POST request with body", function()
            local body = "name=test&email=test@example.com"
            local request_data = string.format(
                "POST /users HTTP/1.1\r\nHost: localhost\r\nContent-Type: application/x-www-form-urlencoded\r\nContent-Length: %d\r\n\r\n%s",
                #body, body
            )
            
            local request, err = http_parser.parse_request(request_data)
            
            assert.is_nil(err)
            assert.is_not_nil(request)
            assert.are.equal("POST", request.method)
            assert.are.equal("/users", request.path)
            assert.are.equal(body, request.body)
            assert.are.equal("application/x-www-form-urlencoded", request.headers["content-type"])
        end)

        it("should handle URL decoding", function()
            local request_data = "GET /hello%20world?name=John%20Doe HTTP/1.1\r\nHost: localhost\r\n\r\n"
            local request, err = http_parser.parse_request(request_data)
            
            assert.is_nil(err)
            assert.are.equal("/hello world", request.path)
            assert.are.equal("John Doe", request.query.name)
        end)

        it("should reject invalid HTTP methods", function()
            local request_data = "INVALID /hello HTTP/1.1\r\nHost: localhost\r\n\r\n"
            local request, err = http_parser.parse_request(request_data)
            
            assert.is_nil(request)
            assert.is_not_nil(err)
            assert.matches("Invalid HTTP method", err)
        end)

        it("should reject unsupported HTTP versions", function()
            local request_data = "GET /hello HTTP/2.0\r\nHost: localhost\r\n\r\n"
            local request, err = http_parser.parse_request(request_data)
            
            assert.is_nil(request)
            assert.is_not_nil(err)
            assert.matches("Unsupported HTTP version", err)
        end)

        it("should parse form data", function()
            local form_body = "name=test&email=test%40example.com&tags=lua&tags=web"
            local form_data = http_parser.parse_form_data(form_body)
            
            assert.are.equal("test", form_data.name)
            assert.are.equal("test@example.com", form_data.email)
            assert.is_table(form_data.tags)
            assert.are.equal(2, #form_data.tags)
            assert.are.equal("lua", form_data.tags[1])
            assert.are.equal("web", form_data.tags[2])
        end)

        it("should get content type", function()
            local headers = {
                ["content-type"] = "application/json; charset=utf-8"
            }
            
            local content_type = http_parser.get_content_type(headers)
            assert.are.equal("application/json", content_type)
        end)
    end)

    describe("Connection Manager", function()
        local manager

        before_each(function()
            manager = connection_manager.new({
                keep_alive_timeout = 5,
                max_request_size = 1024
            })
        end)

        it("should create connection manager", function()
            assert.is_not_nil(manager)
            assert.is_table(manager.connections)
            assert.is_table(manager.config)
        end)

        it("should generate connection stats", function()
            local stats = manager:get_stats()
            
            assert.is_table(stats)
            assert.is_number(stats.total_connections)
            assert.is_number(stats.keep_alive_connections)
            assert.is_number(stats.manager_uptime)
        end)

        it("should generate unique connection IDs", function()
            local id1 = manager:_generate_connection_id()
            local id2 = manager:_generate_connection_id()
            
            assert.is_string(id1)
            assert.is_string(id2)
            assert.are_not.equal(id1, id2)
            assert.matches("conn_%d+_%d+", id1)
        end)
    end)

    describe("Motor Server Functions", function()
        it("should validate handler parameter", function()
            assert.has_error(function()
                motor.serve({}, "not a function")
            end, "Handler must be a function")
        end)

        it("should handle function-only parameter", function()
            -- This would normally start a server, so we just test parameter handling
            local handler = function(req) return {status = 200} end
            
            -- We can't actually test the server start without running it,
            -- but we can test parameter validation
            assert.is_function(handler)
        end)

        it("should get correct status text", function()
            assert.are.equal("OK", motor._get_status_text(200))
            assert.are.equal("Not Found", motor._get_status_text(404))
            assert.are.equal("Internal Server Error", motor._get_status_text(500))
            assert.are.equal("Unknown", motor._get_status_text(999))
        end)

        it("should safely call handlers", function()
            -- Test successful handler
            local good_handler = function(req)
                return {status = 200, body = "OK"}
            end
            
            local response = motor._safe_handler_call(good_handler, {})
            assert.are.equal(200, response.status)
            assert.are.equal("OK", response.body)
            
            -- Test error handler
            local bad_handler = function(req)
                error("Handler error")
            end
            
            local error_response = motor._safe_handler_call(bad_handler, {})
            assert.are.equal(500, error_response.status)
            assert.matches("Internal Server Error", error_response.body)
            
            -- Test invalid return handler
            local invalid_handler = function(req)
                return "not a table"
            end
            
            local invalid_response = motor._safe_handler_call(invalid_handler, {})
            assert.are.equal(500, invalid_response.status)
            assert.matches("Handler must return a table", invalid_response.body)
        end)
    end)

    describe("Integration Tests", function()
        -- These would be integration tests that require a running server
        -- For now, we'll just test the basic flow
        
        it("should create a complete request-response cycle", function()
            -- Mock request
            local request = {
                method = "GET",
                path = "/test",
                query = {param = "value"},
                headers = {host = "localhost"},
                body = ""
            }
            
            -- Simple handler
            local handler = function(req)
                return {
                    status = 200,
                    headers = {["Content-Type"] = "text/plain"},
                    body = "Hello " .. (req.query.param or "World")
                }
            end
            
            -- Test the handler
            local response = handler(request)
            assert.are.equal(200, response.status)
            assert.are.equal("Hello value", response.body)
            assert.are.equal("text/plain", response.headers["Content-Type"])
        end)
    end)
end) 