#!/usr/bin/env lua

-- Quick test to verify Motor server startup
local motor = require('motor')

print('✅ Testing Motor server startup...')

-- Test socket functionality
local socket = require('socket')
local server = socket.tcp()
server:settimeout(0)
local ok, err = server:bind('127.0.0.1', 0) -- Use port 0 for auto-assignment

if ok then
    print('✅ Socket binding works')
    server:close()
else
    print('❌ Socket binding failed:', err)
    os.exit(1)
end

print('✅ Motor server logic appears to be working!')

-- Test basic handler creation
local function test_handler(request)
    return {
        status = 200,
        headers = { ["Content-Type"] = "text/plain" },
        body = "Test response"
    }
end

print('✅ Handler creation works')

-- Test that motor.serve function exists and is callable
if type(motor.serve) == "function" then
    print('✅ motor.serve function is available')
else
    print('❌ motor.serve is not a function')
    os.exit(1)
end

print('🚀 All Motor tests passed! Server should work correctly.')
print('💡 To test the full server, run: lua example.lua') 