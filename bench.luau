--!strict

-- Simple throughput benchmark for Base64 (MB/s)
-- Edit the constants below to change size and iterations.

local SIZE_MB = 1        -- payload size per iteration
local ENC_ITERS = 4     -- starting encode iterations (adaptive)
local DEC_ITERS = 4     -- starting decode iterations (adaptive)

-- Benchmark stability controls (tune as desired)
local WARMUP_SECONDS = 0.25  -- time spent warming up each case
local TARGET_SECONDS = 0.75  -- minimum time per measured sample
local REPEATS = 10            -- number of samples, median reported

-- Load module (support multiple environments)
local Base64
do
    local ok, mod = pcall(require, "./src")
    if ok and type(mod) == "table" then
        Base64 = mod
    else
        ok, mod = pcall(require, "./src.luau")
        if ok and type(mod) == "table" then
            Base64 = mod
        else
            error("Unable to load module src.luau")
        end
    end
end

local MB = 1024*1024
local function makeBuffer(n: number): buffer
    local buf = buffer.create(n)
    local WRITE_U32 = buffer.writeu32
    if WRITE_U32 ~= nil then
        local word = 0x01020304
        local i = 0
        local limit = n - (n % 4)
        while i < limit do
            WRITE_U32(buf, i, word)
            i += 4
        end
        while i < n do
            buffer.writeu8(buf, i, (i % 256))
            i += 1
        end
    else
        for i = 0, n - 1 do
            buffer.writeu8(buf, i, (i % 256))
        end
    end
    return buf
end

local function now(): number
    -- os.clock returns CPU seconds in Luau CLI; suitable for tight loops
    return os.clock()
end

-- Simple utilities for stable measurements
local function sortNumbers(a: {number})
    table.sort(a, function(x, y) return x < y end)
end

local function median(a: {number}): number
    sortNumbers(a)
    local n = #a
    if n == 0 then return 0 end
    if n % 2 == 1 then
        return a[(n+1)//2]
    else
        local i = n//2
        return 0.5*(a[i] + a[i+1])
    end
end

-- Calibrate iterations so each sample runs long enough
local function calibrate(iters: number, runOnce: (number) -> number): number
    if iters < 1 then iters = 1 end
    local t = 0
    while true do
        local t0 = now()
        local acc = 0
        for _ = 1, iters do
            acc += runOnce(0)
        end
        local t1 = now()
        t = t1 - t0
        if t >= TARGET_SECONDS then
            break
        end
        -- Scale up proportionally, with a minimum growth factor
        local scale = TARGET_SECONDS / math.max(t, 1e-9)
        local factor = math.max(2, math.floor(scale + 0.5))
        iters = math.max(iters + 1, iters * factor)
        if iters > 1e9 then break end
    end
    return iters
end

-- Run a benchmark case: warmup, multiple samples, median throughput
local function runCase(bytes: number, startIters: number, runOnce: (number) -> number): number
    -- Warm-up up to WARMUP_SECONDS to stabilize caches and frequency
    do
        local t0 = now()
        local i = 0
        while (now() - t0) < WARMUP_SECONDS do
            runOnce(i)
            i += 1
        end
    end

    -- Calibrate iterations for stable sample durations
    local iters = calibrate(startIters, runOnce)

    -- Collect samples
    local samples = table.create(REPEATS)
    local sink = 0
    for s = 1, REPEATS do
        local t0 = now()
        local acc = 0
        for _ = 1, iters do
            acc += runOnce(s)
        end
        local t1 = now()
        sink += acc -- keep work alive
        local seconds = t1 - t0
        samples[s] = (bytes * iters) / math.max(seconds, 1e-9) / MB
    end

    -- Minor side-effect to prevent over-optimization
    if sink == -1 then print("_") end

    return median(samples)
end

local function benchEncode(bytes: number, startIters: number)
    local encode = Base64.encode
    local inBuf = makeBuffer(bytes)
    local inStr = buffer.tostring(inBuf)

    -- Define per-iteration actions
    local function encBuf(_: number): number
        local out = encode(inBuf)
        return #out
    end
    local function encStr(_: number): number
        local out = encode(inStr)
        return #out
    end

    local enc_buf_mb_s = runCase(bytes, startIters, encBuf)
    local enc_str_mb_s = runCase(bytes, startIters, encStr)

    print(string.format("Encode buffer:  %.2f MB/s (median)", enc_buf_mb_s))
    print(string.format("Encode string:  %.2f MB/s (median)", enc_str_mb_s))
end

local function benchDecode(bytes: number, startIters: number)
    local decode = Base64.decode
    local inBuf = makeBuffer(bytes)
    local b64 = Base64.encode(inBuf)
    local b64buf = buffer.fromstring(b64)

    -- Define per-iteration actions
    local function decStr(_: number): number
        local out = decode(b64)
        return #out
    end
    local function decBuf(_: number): number
        local out = decode(b64buf)
        return #out
    end

    local dec_str_mb_s = runCase(bytes, startIters, decStr)
    local dec_buf_mb_s = runCase(bytes, startIters, decBuf)

    print(string.format("Decode string:  %.2f MB/s (median)", dec_str_mb_s))
    print(string.format("Decode buffer:  %.2f MB/s (median)", dec_buf_mb_s))
end

local bytes = SIZE_MB * MB
print(string.format("Benchmarking with %d MB per iteration", SIZE_MB))
benchEncode(bytes, ENC_ITERS)
benchDecode(bytes, DEC_ITERS)

