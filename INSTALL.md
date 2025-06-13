# Motor Installation Guide

Motor is the coroutine-based HTTP/1.1 server engine for the Foguete web framework.

## Installation

### Method 1: Install from LuaRocks (Recommended)

```bash
luarocks install motor
```

### Method 2: Install from Source

1. Clone the repository:
```bash
git clone https://github.com/foguete/motor.git
cd motor
```

2. Install using LuaRocks:
```bash
luarocks make motor-1.0.0-1.rockspec
```

### Method 3: Local Development

For local development or when working on the Motor package:

```bash
cd motor
luarocks make motor-1.0.0-1.rockspec --local
```

## Dependencies

Motor requires the following dependencies:

- **Lua 5.4+** or **LuaJIT**
- **LuaSocket 3.0+** for TCP socket support

These will be automatically installed by LuaRocks.

## Verification

Test that Motor is installed correctly:

```lua
local motor = require("motor")
print("Motor version:", motor.VERSION)
```

## Usage

### Basic HTTP Server

```lua
local motor = require("motor")

motor.serve({
    host = "127.0.0.1",
    port = 8080
}, function(request)
    return {
        status = 200,
        headers = { ["Content-Type"] = "text/plain" },
        body = "Hello from Motor!"
    }
end)
```

### Advanced Configuration

```lua
local motor = require("motor")

local config = {
    host = "0.0.0.0",
    port = 3000,
    keep_alive_timeout = 30,
    max_request_size = 2 * 1024 * 1024, -- 2MB
    socket_timeout = 5.0
}

motor.serve(config, function(request)
    -- Handle request
    return {
        status = 200,
        headers = { 
            ["Content-Type"] = "application/json",
            ["X-Powered-By"] = "Motor/1.0.0"
        },
        body = '{"message": "Hello World"}'
    }
end)
```

### Request Object

The request object passed to your handler contains:

```lua
{
    method = "GET",           -- HTTP method
    path = "/users/123",      -- Request path
    query = { id = "123" },   -- Parsed query parameters
    headers = { ... },        -- Request headers (lowercase keys)
    body = "...",            -- Request body
    version = "HTTP/1.1"     -- HTTP version
}
```

### Response Object

Your handler should return a response table:

```lua
{
    status = 200,                               -- HTTP status code
    headers = { ["Content-Type"] = "text/html" }, -- Response headers
    body = "<h1>Hello World</h1>"               -- Response body
}
```

## Module Structure

When installed, Motor provides these modules:

- `motor` - Main server module
- `motor.http_parser` - HTTP request parser
- `motor.connection_manager` - Connection management

## Integration with Foguete

Motor is designed to work with other Foguete packages:

```lua
local motor = require("motor")
local rota = require("rota")      -- Router
local comando = require("comando") -- Controllers

-- Set up routing
local router = rota.new()
router:get("/", "HomeController@index")

-- Start server
motor.serve({ port = 8080 }, function(request)
    return router:handle(request)
end)
```

## Testing

Run the test suite:

```bash
cd motor
busted spec/
```

## Troubleshooting

### Common Issues

**"module 'socket' not found"**
```bash
luarocks install luasocket
```

**"Permission denied" when binding to port**
- Use a port > 1024 for non-root users
- Or run with sudo for ports < 1024

**High memory usage**
- Adjust `max_request_size` in config
- Monitor keep-alive connections

### Getting Help

- Check the [README](README.md) for basic usage
- Review the [examples](example.lua)
- Open an issue on GitHub for bugs

## License

Motor is released under the MIT License. 