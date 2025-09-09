--!strict
-- Simple throughput benchmark for Base64 encode/decode
-- Usage:
--   lune run bench.luau               -- defaults: 16 MB, ~1s per test
--   SIZE_MB=64 SECONDS=2 lune run bench.luau


local Base64 = require("./src")

local SIZE_MB = 64
local MIN_SECONDS = 1.0

-- Build deterministic raw payload of SIZE_MB megabytes
local function makeRawBytes(nBytes: number): string
    -- Repeating ASCII chunk (non-trivial distribution)
    local chunk = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ~!@#$%^&*()_+=-[]{}|;:,.<>/?"
    local rep = math.ceil(nBytes / #chunk)
    local s = string.rep(chunk, rep)
    return string.sub(s, 1, nBytes)
end

local function mb(nBytes: number): number
    return nBytes / 1e6
end

local function now(): number
    -- os.clock is CPU time and stable for benchmarking
    return os.clock()
end

local REPEATS = 16
local USE_MEBI = true

local function bytesToMB(n: number): number
    if USE_MEBI then return n / (1024*1024) end
    return n / 1e6
end

local function measure(label: string, bytesPerIter: number, fn: () -> ())
    -- Quick warmup
    fn(); fn()
    local best = 1e9
    for _ = 1, 5 do
        local t0 = now(); fn(); local dt = now() - t0
        if dt > 0 and dt < best then best = dt end
    end
    if best == 1e9 then best = 1e-6 end

    local iters = math.max(1, math.ceil(MIN_SECONDS / best))

    local results = table.create(REPEATS)
    local totalBytes = bytesPerIter * iters

    for r = 1, REPEATS do
        local t1 = now()
        for _ = 1, iters do fn() end
        local dt = now() - t1
        results[r] = (totalBytes / dt) / 1e6 -- MB/s (1e6 bytes)
    end

    table.sort(results)
    local median = results[math.ceil(REPEATS/2)]
    local minv, maxv = results[1], results[#results]
    print(string.format(
        "%s: median %.2f MB/s  [min %.2f, max %.2f]  (bytes=%.2f %sB, iters=%d, repeats=%d)",
        label, median, minv, maxv,
        bytesToMB(totalBytes), USE_MEBI and "Mi" or "M", iters, REPEATS
    ))
end

do
    print(string.format("Payload: %.1f %sB (SIZE_MB), min time: %.2fs, repeats: %d", SIZE_MB, USE_MEBI and "Mi" or "M", MIN_SECONDS, REPEATS))

    local unit = USE_MEBI and (1024*1024) or 1e6
    local rawBytes = math.floor(SIZE_MB * unit + 0.5)
    local raw = makeRawBytes(rawBytes)

    -- Prefer passing buffers into API to focus on hot path
    local rawBuf = buffer.fromstring(raw)

    -- Prepare corresponding Base64 input once (not timed)
    local b64 = Base64.encode(rawBuf)
    local b64Buf = buffer.fromstring(b64)

    -- Report size expansion for context
    print(string.format("Sizes: raw=%.2f %sB -> b64=%.2f %sB", bytesToMB(#raw), USE_MEBI and "Mi" or "M", bytesToMB(#b64), USE_MEBI and "Mi" or "M"))

    -- Encode: count original raw bytes per second
    measure("Encode", #raw, function()
        -- Pass buffer to avoid string->buffer overhead inside encode
        Base64.encode(rawBuf)
    end)

    -- Decode: count decoded output bytes per second (i.e., original size)
    measure("Decode", #raw, function()
        -- Pass buffer containing base64 text to avoid string->buffer overhead
        Base64.decode(b64Buf)
    end)
end
