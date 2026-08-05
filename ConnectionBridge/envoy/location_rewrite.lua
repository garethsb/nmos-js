-- Rewrite Connection API Bridge upstream 3xx Location headers so the
-- browser stays on the bridge for Connection API, and Device same-origin
-- redirects to other Node paths remain reachable.
--
-- Path-relative Locations are left alone (they already resolve against the
-- bridge request URL).
-- Path-absolute Locations under this target's Connection API base path are
-- rewritten onto the bridge path.
-- Path-absolute Locations outside that base (e.g. /x-manifest/...) are
-- re-absolutized onto the preferred upstream candidate so the browser
-- follows to the Device (Envoy Lua cannot read the host actually selected
-- for this request).
-- Protocol-relative and absolute Locations are rewritten onto the bridge
-- only when their host/port match one of this target's upstream Device
-- authorities (all Connection API candidates); the new Location uses the
-- client's bridge scheme/host/port. Absolute Locations use http(s) only
-- (phase 1). Locations that point at any other authority are left unchanged.
--
-- Per-route context is set into dynamic metadata namespace
-- nmos_bridge_location by the nmos.bridge.location_meta Lua filter
-- (LuaPerRoute from the adapter). This script stores the client
-- scheme/authority into the same namespace and rewrites Location on 3xx.

local DYN = "nmos_bridge_location"

local function split_host_port(host, scheme)
    local default_port = (scheme == "https") and "443" or "80"
    -- IPv6 with port: [addr]:port
    local h, p = host:match("^%[([^%]]+)%]:(%d+)$")
    if h then
        return h, p
    end
    -- IPv6 without port: [addr]
    h = host:match("^%[([^%]]+)%]$")
    if h then
        return h, default_port
    end
    -- reg-name / IPv4 with port
    h, p = host:match("^([^:]+):(%d+)$")
    if h then
        return h, p
    end
    return host, default_port
end

local function parse_authority_pathquery(rest, default_scheme)
    local authority, pathquery = rest:match("^([^/?#]+)(.*)$")
    if not authority then
        return nil
    end
    if pathquery == nil or pathquery == "" then
        pathquery = "/"
    end
    local host, port = split_host_port(authority, default_scheme)
    return host, port, pathquery
end

-- Normalize http(s) scheme (RFC schemes are case-insensitive).
local function parse_absolute(url)
    local s_flag, rest = url:match("^[Hh][Tt][Tt][Pp]([Ss]?)://(.+)$")
    if not rest then
        return nil
    end
    local scheme = (s_flag ~= nil and s_flag ~= "") and "https" or "http"
    local host, port, pathquery = parse_authority_pathquery(rest, scheme)
    if not host then
        return nil
    end
    return scheme, host, port, pathquery
end

local function suffix_under_base(pathquery, base_path)
    local path, rest = pathquery:match("^([^?#]*)(.*)$")
    if path == nil then
        return nil
    end
    if path == base_path then
        return "", rest
    end
    local prefix = base_path .. "/"
    if path:sub(1, #prefix) == prefix then
        return path:sub(#base_path + 1), rest
    end
    return nil
end

local function authority_key(host, port)
    return host:lower() .. ":" .. port
end

local function matches_upstream(loc_scheme, loc_host, loc_port, upstream_scheme, upstream_authorities)
    if loc_scheme ~= upstream_scheme then
        return false
    end
    local want = authority_key(loc_host, loc_port)
    for entry in string.gmatch(upstream_authorities, "[^,]+") do
        local host, port = split_host_port(entry, upstream_scheme)
        if authority_key(host, port) == want then
            return true
        end
    end
    return false
end

local function rewrite_onto_bridge(pathquery, base_path, bridge_path, bridge_scheme, bridge_host)
    local suffix, rest = suffix_under_base(pathquery, base_path)
    if suffix == nil then
        return nil
    end
    return bridge_scheme .. "://" .. bridge_host .. bridge_path .. suffix .. rest
end

-- First entry in the adapter's priority-sorted candidate list.
local function preferred_upstream_authority(upstream_authorities)
    return upstream_authorities:match("^[^,]+")
end

local function rewrite_location(
    location,
    base_path,
    bridge_path,
    bridge_scheme,
    bridge_host,
    upstream_scheme,
    upstream_authorities
)
    -- empty Location
    if location == nil or location == "" then
        return nil
    end

    -- protocol-relative //authority/... (same authority rules as absolute)
    if location:sub(1, 2) == "//" then
        local host, port, pathquery =
            parse_authority_pathquery(location:sub(3), upstream_scheme)
        -- unparseable protocol-relative URL
        if not host then
            return nil
        end
        -- protocol-relative Location for a different authority
        if
            not matches_upstream(
                upstream_scheme,
                host,
                port,
                upstream_scheme,
                upstream_authorities
            )
        then
            return nil
        end
        return rewrite_onto_bridge(
            pathquery,
            base_path,
            bridge_path,
            bridge_scheme,
            bridge_host
        )
    end

    -- path-absolute
    if location:sub(1, 1) == "/" then
        local suffix, rest = suffix_under_base(location, base_path)
        -- under Connection API base path -> stay on the bridge
        if suffix ~= nil then
            return bridge_path .. suffix .. rest
        end
        -- outside base (e.g. /x-manifest/): Device same-origin via preferred candidate
        local authority = preferred_upstream_authority(upstream_authorities)
        if authority == nil or authority == "" then
            return nil
        end
        return upstream_scheme .. "://" .. authority .. location
    end

    -- path-relative: leave alone (browser resolves against the bridge URL)
    if not location:match("^[A-Za-z][A-Za-z0-9+.-]*:") then
        return nil
    end
    -- non-http(s) absolute: unexpected; leave alone
    if not location:match("^[Hh][Tt][Tt][Pp][Ss]?://") then
        return nil
    end

    local loc_scheme, loc_host, loc_port, pathquery = parse_absolute(location)
    -- unparseable absolute URL
    if not loc_scheme then
        return nil
    end
    -- absolute Location for a different authority
    if
        not matches_upstream(
            loc_scheme,
            loc_host,
            loc_port,
            upstream_scheme,
            upstream_authorities
        )
    then
        return nil
    end
    return rewrite_onto_bridge(
        pathquery,
        base_path,
        bridge_path,
        bridge_scheme,
        bridge_host
    )
end

function envoy_on_request(request_handle)
    local headers = request_handle:headers()
    local host = headers:get(":authority") or headers:get("host")
    local scheme = headers:get("x-forwarded-proto")
    if scheme == nil or scheme == "" then
        scheme = headers:get(":scheme")
    end
    if scheme == nil or scheme == "" then
        scheme = "http"
    end
    if host == nil or host == "" then
        return
    end
    local md = request_handle:streamInfo():dynamicMetadata()
    md:set(DYN, "host", host)
    md:set(DYN, "scheme", scheme)
end

function envoy_on_response(response_handle)
    local status = tonumber(response_handle:headers():get(":status"))
    if status == nil or status < 300 or status >= 400 then
        return
    end
    local location = response_handle:headers():get("location")
    if location == nil or location == "" then
        return
    end

    local dyn = response_handle:streamInfo():dynamicMetadata():get(DYN)
    if dyn == nil then
        return
    end
    local base_path = dyn["base_path"]
    local bridge_path = dyn["bridge_path"]
    local upstream_scheme = dyn["upstream_scheme"]
    local upstream_authorities = dyn["upstream_authorities"]
    local bridge_host = dyn["host"]
    local bridge_scheme = dyn["scheme"]
    if
        base_path == nil
        or bridge_path == nil
        or upstream_scheme == nil
        or upstream_authorities == nil
        or bridge_host == nil
        or bridge_scheme == nil
    then
        return
    end

    local rewritten = rewrite_location(
        location,
        base_path,
        bridge_path,
        bridge_scheme,
        bridge_host,
        upstream_scheme,
        upstream_authorities
    )
    if rewritten ~= nil and rewritten ~= location then
        response_handle:headers():replace("location", rewritten)
    end
end
