const test = require("@std/test")
const RateLimit = require("@src/storage/rateLimit")

const CONFIG: RateLimit.Config = { capacity = 20, refillRate = 10 }

const function drain(at: number)
    local bucket = RateLimit.newBucket(CONFIG, at)
    for _ = 1, CONFIG.capacity do
        local _
        _, bucket = RateLimit.consume(bucket, CONFIG, at)
    end
    return bucket
end

test.suite("RateLimit", function(suite)
    suite:case("allowsBurstUpToCapacity", function(asserts)
        local bucket = RateLimit.newBucket(CONFIG, 0)
        for _ = 1, 20 do
            local ok
            ok, bucket = RateLimit.consume(bucket, CONFIG, 0)
            asserts.eq(true, ok)
        end
    end)

    suite:case("blocksAfterCapacity", function(asserts)
        local bucket = drain(0)
        const ok = RateLimit.consume(bucket, CONFIG, 0)
        asserts.eq(false, ok)
    end)

    suite:case("refillsOverTime", function(asserts)
        local bucket = drain(0)
        const ok, next = RateLimit.consume(bucket, CONFIG, 0.5)
        asserts.eq(true, ok)
        asserts.eq(4, next.tokens)
    end)

    suite:case("neverExceedsCapacity", function(asserts)
        local bucket = RateLimit.newBucket(CONFIG, 0)
        local _
        _, bucket = RateLimit.consume(bucket, CONFIG, 1_000)
        asserts.eq(19, bucket.tokens)
    end)

    suite:case("backwardClockGrantsNothing", function(asserts)
        const bucket = drain(100)
        const ok = RateLimit.consume(bucket, CONFIG, 50)
        asserts.eq(false, ok)
    end)

    suite:case("backwardClockCannotBeFarmed", function(asserts)
        local bucket = drain(100)
        for _, t in { 50, 60, 70, 80 } do
            local ok
            ok, bucket = RateLimit.consume(bucket, CONFIG, t)
            asserts.eq(false, ok)
        end
    end)

    suite:case("resumesRefillPastOriginalAnchor", function(asserts)
        const bucket = drain(100)
        local _, mid = RateLimit.consume(bucket, CONFIG, 50)
        const ok, next = RateLimit.consume(mid, CONFIG, 100.5)
        asserts.eq(true, ok)
        asserts.eq(4, next.tokens)
    end)
end)
