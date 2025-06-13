#!/usr/bin/env lua

-- Quick test of HTTP parser
local parser = require('motor.http_parser')

local req = 'GET /hello?name=World HTTP/1.1\r\nHost: localhost\r\nUser-Agent: test\r\n\r\n'
local parsed, err = parser.parse_request(req)

if parsed then
  print('✅ HTTP Parser working!')
  print('Method:', parsed.method)
  print('Path:', parsed.path)
  print('Query name:', parsed.query.name)
  print('Host header:', parsed.headers.host)
else
  print('❌ Parser failed:', err)
end

-- Test URL decoding
local decoded = parser._url_decode("hello%20world%21")
print('URL decode test:', decoded) 