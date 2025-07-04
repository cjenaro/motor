-- HTTP Parser for Motor
-- Parses HTTP/1.1 requests into Lua tables

---@class HttpParser
local http_parser = {}

-- Parse a complete HTTP request string
---@param request_data string Raw HTTP request data
---@return HttpRequest|nil, string? Parsed request or nil with error message
function http_parser.parse_request(request_data)
	if type(request_data) ~= "string" or request_data == "" then
		return nil, "Empty or invalid request data"
	end

	-- Split headers and body
	local headers_end = string.find(request_data, "\r\n\r\n")
	if not headers_end then
		return nil, "Invalid HTTP request format"
	end

	local headers_part = string.sub(request_data, 1, headers_end - 1)
	local body_part = string.sub(request_data, headers_end + 4)

	-- Parse request line and headers
	local lines = http_parser._split_lines(headers_part)
	if #lines == 0 then
		return nil, "Missing request line"
	end

	-- Parse request line (first line)
	local method, path, version = http_parser._parse_request_line(lines[1])
	if not method or not path then
		return nil, "Invalid request line: " .. tostring(path or "unknown error")
	end

	-- Parse headers (remaining lines)
	local headers = {}
	for i = 2, #lines do
		local name, value = http_parser._parse_header_line(lines[i])
		if name then
			headers[name] = value
		end
	end

	-- Parse query parameters from path (path is guaranteed to be non-nil here)
	local clean_path, query_params = http_parser._parse_path_and_query(path)

	-- Parse request body based on content-type
	local parsed_body = {}
	local content_type = http_parser.get_content_type(headers)

	if body_part and body_part ~= "" then
		if content_type == "application/x-www-form-urlencoded" then
			parsed_body = http_parser.parse_form_data(body_part)
		elseif content_type == "application/json" then
			local json_data = http_parser.parse_json(body_part)
			if json_data then
				parsed_body = json_data
			else
				-- Keep raw body if JSON parsing fails
				parsed_body = {}
			end
		end
		-- For other content types (multipart/form-data, text/plain, etc.),
		-- keep raw body and let application handle it
	end

	-- Build request table
	local request = {
		method = method,
		path = clean_path,
		query = query_params,
		headers = headers,
		body = body_part, -- Raw body for backward compatibility
		data = parsed_body, -- Parsed body data
		version = version,
	}

	return request
end

-- Split text into lines, handling different line ending styles
---@param text string Text to split into lines
---@return string[] Array of lines
function http_parser._split_lines(text)
	local lines = {}
	for line in string.gmatch(text, "[^\r\n]+") do
		table.insert(lines, line)
	end
	return lines
end

-- Parse the HTTP request line (GET /path HTTP/1.1)
---@param line string Request line to parse
---@return string?, string?, string?
function http_parser._parse_request_line(line)
	local method, path, version = string.match(line, "^(%S+)%s+(%S+)%s+(%S+)$")

	if not method or not path or not version then
		return nil, "Invalid request line format", nil
	end

	-- Validate HTTP method
	local valid_methods = {
		GET = true,
		POST = true,
		PUT = true,
		DELETE = true,
		HEAD = true,
		OPTIONS = true,
		PATCH = true,
	}

	if not valid_methods[string.upper(method)] then
		return nil, "Invalid HTTP method: " .. method, nil
	end

	-- Validate HTTP version
	if not string.match(version, "^HTTP/1%.[01]$") then
		return nil, "Unsupported HTTP version: " .. version, nil
	end

	return string.upper(method), path, version
end

-- Parse a header line (Name: Value)
---@param line string Header line to parse
---@return string|nil, string|nil Header name and value or nil for both if malformed
function http_parser._parse_header_line(line)
	local name, value = string.match(line, "^([^:]+):%s*(.*)$")

	if not name or not value then
		return nil, nil -- Skip malformed headers
	end

	-- Normalize header name to lowercase
	name = string.lower(string.gsub(name, "%s+$", "")) -- trim trailing spaces
	value = string.gsub(value, "%s+$", "") -- trim trailing spaces

	return name, value
end

-- Parse path and query parameters
---@param full_path string Full path with optional query string
---@return string, table<string, string> Clean path and query parameters table
function http_parser._parse_path_and_query(full_path)
	local path, query_string = string.match(full_path, "^([^%?]*)%??(.*)$")

	if not path then
		path = full_path
		query_string = ""
	end

	-- URL decode path
	path = http_parser._url_decode(path)

	-- Parse query parameters
	local query_params = {}
	if query_string and query_string ~= "" then
		for pair in string.gmatch(query_string, "[^&]+") do
			local key, value = string.match(pair, "^([^=]*)=?(.*)$")
			if key then
				key = http_parser._url_decode(key)
				value = http_parser._url_decode(value or "")

				-- Handle multiple values for same key
				if query_params[key] then
					if type(query_params[key]) == "table" then
						table.insert(query_params[key], value)
					else
						query_params[key] = { query_params[key], value }
					end
				else
					query_params[key] = value
				end
			end
		end
	end

	return path, query_params
end

-- URL decode a string
---@param str string? String to decode
---@return string Decoded string
function http_parser._url_decode(str)
	if not str then
		return ""
	end

	-- Replace plus signs with spaces
	str = string.gsub(str, "+", " ")

	-- Replace percent-encoded characters
	str = string.gsub(str, "%%(%x%x)", function(hex)
		return string.char(tonumber(hex, 16))
	end)

	return str
end

-- Parse URL-encoded form data (application/x-www-form-urlencoded)
---@param body string Form data body
---@return table<string, string|string[]> Parsed form data
function http_parser.parse_form_data(body)
	local form_data = {}

	if not body or body == "" then
		return form_data
	end

	for pair in string.gmatch(body, "[^&]+") do
		local key, value = string.match(pair, "^([^=]*)=?(.*)$")
		if key then
			key = http_parser._url_decode(key)
			value = http_parser._url_decode(value or "")

			-- Handle multiple values for same key
			if form_data[key] then
				if type(form_data[key]) == "table" then
					table.insert(form_data[key], value)
				else
					form_data[key] = { form_data[key], value }
				end
			else
				form_data[key] = value
			end
		end
	end

	return form_data
end

-- Parse JSON request body
---@param body string JSON body
---@return table|nil, string? Parsed JSON data or nil with error message
function http_parser.parse_json(body)
	if not body or body == "" then
		return {}
	end

	-- Use dkjson for safe JSON parsing
	local require_ok, json = pcall(require, "dkjson")
	if not require_ok then
		return nil, "JSON library not available"
	end

	local result, _, decode_err = json.decode(body)
	if result then
		return result
	else
		return nil, "Invalid JSON: " .. tostring(decode_err)
	end
end

-- Get content type from headers
---@param headers table<string, string> HTTP headers
---@return string Content type (main type only, without parameters)
function http_parser.get_content_type(headers)
	local content_type = headers["content-type"] or ""
	local main_type = string.match(content_type, "^([^;]+)")
	return string.lower(main_type or "")
end

return http_parser
