# Base64 (Luau)

Lightning-fast Base64 that runs entirely in pure Luau.<br>
It's built for throughput on large payloads and low overhead on small ones.<br>

This project was supposed to be an AI code optimization race first!<br>
Read more about it below!

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

### AI Race Results 🏁

I placed a few models against each other to squeeze the most speed out of a brand-new Base64 implementation. Here's how they placed, with quick notes on style and performance.

| Place | Model | Highlights | Comments |
|:-----:|--------------------|---------------------------------------------------------------------------|-----------------------------|
| 1st | GPT-5 Thinking | Fastest by round 3, managed to achieve 60mb/s on old hardware without any help. | Was slower than  Claude 4.1 at the start |
| 2nd | Grok 4 Thinking | Won first two rounds: tidy code, failed on later optimizations | Strong start |
| 3rd | Claude 4.1 Sonnet | Clean, readable code, decent speed, stopped improving after a few prompts | Elegant code |
| 4th | Gemini 2.5 Pro | Very tidy and readable, but consistently slow | Not performance-focused |

Notes:

- Rules: I kept changes comparable round-to-round, so every code would be comparable and similar to eachother. Models would have to find the fastest way themselves.
- Eureka: AI models that favored unrolling hot loops, avoiding `bit32` where math ops suffice, and memory-friendly access patterns
- Result: GPT-5 Thinking lost early rounds, then delivered the fastest variant by round 3 and beyond.

P.S: GPT-5 managed to somehow provide slower code by round 4 but we won't talk about that...

After finding out that it could write code this fast I changed my objective; "Can AI actually race against optimizations done by real humans?"
This repository is the result of that.
I gave GPT-5 the third round's fastest (it's own code) and told it to aggressively optimize it.
It went up to 65mb/s that time, so then I cheated a little and prompted the model to unroll loops, use math over bit32, and abused (lol) it to prioritize memory access patterns.
On this change I made 9 different iterations.

The 7th iteration it got up to 100mb/s on my FX-8300, thats reaally high speeds for my fossil cpu.
Racing it agains publicly available fast luau base64 implementations showed that this one was the fastest (that I could find) yet.

So here we are, I made a repository on it and released it for everyone to benefit off of it so go ahead and use it now! <br>
It's licensed with **UNLICENSE** and I ask for ZERO clout, just hope you finally finish that back-end project!! :pray:

## FAQ

- **Q:** I don't want to use trashy AI code... I want code made by real people!
- **A:** Check out [Lute's Base64 implementation](https://github.com/luau-lang/lute/blob/primary/batteries/base64.luau) which provides comparable performance.

~ Token