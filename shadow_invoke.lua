local http = require "resty.http"
local httpc = http.new()
httpc:set_timeout(5000)
local cjson = require("cjson")

local ngx_log = ngx.log
local ngx_ERR = ngx.ERR

ngx.req.read_body()
local request_body = cjson.encode(ngx.req.get_body_data())
local method = ngx.var.request_method
ngx.req.set_header("Accept-Encoding", "identity")
local request_headers = ngx.req.get_headers()
local correlation_id = request_headers["correlation_id"]
local random_number = math.random(1, 100)

