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
    const anchor = math.max(bucket.lastRefill, now)
    const elapsed = anchor - bucket.lastRefill
    const refilled = math.min(config.capacity, bucket.tokens + elapsed * config.refillRate)

    if refilled < 1 then
        return false, { tokens = refilled, lastRefill = anchor }
    end

    return true, { tokens = refilled - 1, lastRefill = anchor }
end

return table.freeze(RateLimit)
