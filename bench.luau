--!strict

-- Simple throughput benchmark for Base64 (MB/s)
-- Edit the constants below to change size and iterations.

local SIZE_MB = 96     -- payload size per iteration
local ENC_ITERS = 10   -- encode iterations
local DEC_ITERS = 10   -- decode iterations

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

local function benchEncode(bytes: number, iters: number)
    local inBuf = makeBuffer(bytes)
    local inStr = buffer.tostring(inBuf)

    -- Warm-up
    Base64.encode(inBuf)
    Base64.encode(inStr)

    -- Buffer input
    local t0 = now()
    local acc = 0
    for _ = 1, iters do
        local out = Base64.encode(inBuf)
        acc += #out
    end
    local t1 = now()
    local enc_buf_mb_s = (bytes * iters) / (t1 - t0) / MB

    -- String input (includes string->buffer cost in API)
    t0 = now()
    acc = 0
    for _ = 1, iters do
        local out = Base64.encode(inStr)
        acc += #out
    end
    t1 = now()
    local enc_str_mb_s = (bytes * iters) / (t1 - t0) / MB

    print(string.format("Encode buffer:  %.2f MB/s", enc_buf_mb_s))
    print(string.format("Encode string:  %.2f MB/s", enc_str_mb_s))
end

local function benchDecode(bytes: number, iters: number)
    local inBuf = makeBuffer(bytes)
    local b64 = Base64.encode(inBuf)

    -- Warm-up
    Base64.decode(b64)
    Base64.decode(buffer.fromstring(b64))

    -- String input
    local t0 = now()
    local acc = 0
    for _ = 1, iters do
        local out = Base64.decode(b64)
        acc += #out
    end
    local t1 = now()
    local dec_str_mb_s = (bytes * iters) / (t1 - t0) / MB

    -- Buffer input
    local b64buf = buffer.fromstring(b64)
    t0 = now()
    acc = 0
    for _ = 1, iters do
        local out = Base64.decode(b64buf)
        acc += #out
    end
    t1 = now()
    local dec_buf_mb_s = (bytes * iters) / (t1 - t0) / MB

    print(string.format("Decode string:  %.2f MB/s", dec_str_mb_s))
    print(string.format("Decode buffer:  %.2f MB/s", dec_buf_mb_s))
end

local bytes = SIZE_MB * MB
print(string.format("Benchmarking with %d MB per iteration", SIZE_MB))
benchEncode(bytes, ENC_ITERS)
benchDecode(bytes, DEC_ITERS)

