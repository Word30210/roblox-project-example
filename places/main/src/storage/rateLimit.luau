export type Bucket = {
    read tokens: number,
    read lastRefill: number,
}

export type Config = {
    capacity: number,
    refillRate: number,
}

const RateLimit = {}

function RateLimit.newBucket(config: Config, now: number): Bucket
    return table.freeze({
        tokens = config.capacity,
        lastRefill = now,
    })
end

function RateLimit.consume(bucket: Bucket, config: Config, now: number): (boolean, Bucket)
    const elapsed = math.max(0, now - bucket.lastRefill)
    const refilled = math.min(config.capacity, bucket.tokens + elapsed * config.refillRate)

    if refilled < 1 then
        return false, table.freeze({ tokens = refilled, lastRefill = now })
    end

    return true, table.freeze({ tokens = refilled - 1, lastRefill = now })
end

return table.freeze(RateLimit)
