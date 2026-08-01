const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Clicker = require("@game/ReplicatedStorage/shared/clicker")
const RateLimit = require("@game/ServerStorage/storage/rateLimit")

const Remotes = ReplicatedStorage.remotes
const increaseScore = Remotes.increaseScore
const syncScore = Remotes.syncScore

const scoreValues: { [Player]: IntValue } = {}
const clickers: { [Player]: Clicker.Clicker } = {}
const buckets: { [Player]: RateLimit.Bucket } = {}

const CLICK_LIMIT: RateLimit.Config = { capacity = 20, refillRate = 10 }

const function onPlayerAdded(player: Player)
    const leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = player

    const score = Instance.new("IntValue")
    score.Name = "Score"
    score.Value = 0
    score.Parent = leaderstats

    scoreValues[player] = score
    clickers[player] = Clicker.new()
    buckets[player] = RateLimit.newBucket(CLICK_LIMIT, os.clock())
end

const function onPlayerRemoving(player: Player)
    const scoreValue = scoreValues[player]
    scoreValue:Destroy()
    scoreValues[player] = nil
    buckets[player] = nil
end

const function onIncreasingScore(player: Player)
    const bucket = buckets[player]
    if not bucket then
        return
    end

    const allowed, nextBucket = RateLimit.consume(bucket, CLICK_LIMIT, os.clock())
    buckets[player] = nextBucket

    if not allowed then
        syncScore:FireClient(player, scoreValues[player].Value)
        return
    end

    clickers[player] = Clicker.click(clickers[player])
    scoreValues[player].Value = clickers[player].score
end

for _, player in Players:GetPlayers() do
    task.spawn(onPlayerAdded, player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

increaseScore.OnServerEvent:Connect(onIncreasingScore)
