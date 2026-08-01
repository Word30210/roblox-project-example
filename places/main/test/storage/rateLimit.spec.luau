const test = require("@std/test")
const RateLimit = require("@src/storage/rateLimit")

const CONFIG: RateLimit.Config = { capacity = 20, refillRate = 10 }

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
        local bucket = RateLimit.newBucket(CONFIG, 0)
        for _ = 1, 20 do
            local _
            _, bucket = RateLimit.consume(bucket, CONFIG, 0)
        end
        const ok = RateLimit.consume(bucket, CONFIG, 0)
        asserts.eq(false, ok)
    end)

    suite:case("refillsOverTime", function(asserts)
        local bucket = RateLimit.newBucket(CONFIG, 0)
        for _ = 1, 20 do
            local _
            _, bucket = RateLimit.consume(bucket, CONFIG, 0)
        end
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

    suite:case("survivesBackwardClock", function(asserts)
        local bucket = RateLimit.newBucket(CONFIG, 100)
        const ok, next = RateLimit.consume(bucket, CONFIG, 50)
        asserts.eq(true, ok)
        asserts.eq(19, next.tokens)
    end)
end)
