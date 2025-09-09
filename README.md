# Base64 (Luau) — ultra‑fast, pure Luau

Lightning‑fast Base64 that runs entirely in pure Luau.
It's built for throughput on large payloads and low overhead on small ones.

---
This project was made with GPT-5-Thinking Medium!
Though, with some help... by itself, it kept not optimizing hot paths enough, and kept insisting that unrolling loops wouldn't be good (for some reason?? i don't really know why). Finally after about 10 new chats I managed to get it to unroll loops, use math operators in place of bit32 and favor memory access patterns more.

In the future I will definitely rely less on AI, it was more of a hustle than if I were to make it myself.

Please don't hate me for doing this!
It's for the greater good trust...

~ Token

## Usage

```luau
local Base64 = require("./base64") -- rename as needed

local s = "hello world"
local b64 = Base64.encode(s)
print(b64) -- aGVsbG8gd29ybGQ=

local raw = Base64.decode(b64)
print(raw) -- hello world

-- You can also pass buffers directly
local buf = buffer.fromstring(s)
local b64b = Base64.encode(buf)
```

~ GPT-5
