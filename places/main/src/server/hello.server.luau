const Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

const Remotes = ReplicatedStorage.remotes
const increaseScore = Remotes.increaseScore

const scoreValues: { [Player]: IntValue } = {}

const function onPlayerAdded(player: Player)
    const leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = player

    const score = Instance.new("IntValue")
    score.Name = "Score"
    score.Value = 0
    score.Parent = leaderstats

    scoreValues[player] = score
end

const function onPlayerRemoving(player: Player)
    const scoreValue = scoreValues[player]
    scoreValue:Destroy()
    scoreValues[player] = nil
end

const function onIncreasingScore(player: Player)
    if scoreValues[player] then
        scoreValues[player].Value += 1
    end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

increaseScore.OnServerEvent:Connect(onIncreasingScore)
