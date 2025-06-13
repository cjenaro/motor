package = "motor"
version = "0.0.1-1"
source = {
   url = "git+https://github.com/foguete/motor.git",
   tag = "v0.0.1"
}
description = {
   summary = "Coroutine-based HTTP/1.1 server engine for the Foguete web framework",
   detailed = [[
      Motor is a pure Lua HTTP/1.1 server implementation designed for the Foguete web framework.
      It features coroutine-based concurrency, keep-alive connection support, and efficient
      request/response handling. Motor is built to be lightweight and dependency-free while
      providing all the features needed for modern web applications.
      
      Key Features:
      - Pure Lua implementation (no C dependencies)
      - Coroutine-based non-blocking I/O
      - HTTP/1.1 protocol support with keep-alive
      - URL and form data parsing
      - Connection pooling and management
      - Comprehensive error handling
      - Extensible middleware support
   ]],
   homepage = "https://github.com/foguete/motor",
   license = "MIT"
}
dependencies = {
   "lua >= 5.4",
   "luasocket >= 3.0"
}
supported_platforms = {
   "unix", "macosx", "windows"
}
build = {
   type = "builtin",
   modules = {
      -- Main motor module
      ["motor"] = "src/init.lua",
      -- Internal modules  
      ["motor.http_parser"] = "src/http_parser.lua",
      ["motor.connection_manager"] = "src/connection_manager.lua"
   },
   copy_directories = {
      "spec"
   }
} 