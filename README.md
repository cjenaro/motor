# Motor - HTTP Server Engine 🔧

Motor is the coroutine-based HTTP/1.1 server that powers Foguete applications.

## Features

- **Pure Lua Implementation** - No C dependencies
- **Coroutine-Based** - Non-blocking I/O with coroutines
- **HTTP/1.1 Compatible** - Full protocol support
- **Keep-Alive Support** - Efficient connection reuse
- **Lightweight** - Minimal memory footprint

## Quick Start

```lua
local motor = require("foguete.motor")

-- Simple server
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

## API Reference

### `motor.serve(opts, handler)`
Start the HTTP server with the given options and request handler.

**Parameters:**
- `opts` - Server configuration
  - `host` - IP address to bind (default: "127.0.0.1")
  - `port` - Port number (default: 8080)
  - `backlog` - Connection backlog (default: 128)
- `handler` - Function that processes requests

### Request Format
```lua
{
    method = "GET",
    path = "/users/123",
    query = { id = "123" },
    headers = { ["user-agent"] = "..." },
    body = "request body"
}
```

### Response Format
```lua
{
    status = 200,
    headers = { ["Content-Type"] = "application/json" },
    body = '{"message": "success"}'
}
```

## Architecture

Motor uses Lua coroutines to handle multiple connections efficiently:

1. **Main Loop** - Accepts new connections
2. **Request Coroutines** - Each request runs in its own coroutine
3. **Yielding I/O** - All socket operations yield control
4. **Connection Pooling** - Keep-alive connections are reused

## Performance

Motor is designed for moderate traffic web applications. For high-performance needs, consider:

- Using LuaJIT instead of Lua 5.4
- Tuning socket buffer sizes
- Implementing connection pooling
- Adding HTTP/2 support (future enhancement)

## Contributing

Motor follows the Foguete coding standards:
- All socket operations must yield
- Use proper error handling
- Include comprehensive tests
- Maintain HTTP/1.1 compliance
