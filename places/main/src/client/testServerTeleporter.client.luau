const Players = game:GetService("Players")
const TeleportService = game:GetService("TeleportService")
const TextChatService = game:GetService("TextChatService")

const TEST_SERVER_PLACE_ID = 95960951805084

const command = TextChatService:WaitForChild("TextChatCommands"):WaitForChild("teleportToTestServer")

command.Triggered:Connect(function(source)
    const player = Players:GetPlayerByUserId(source.UserId)
    if player then
        TeleportService:Teleport(TEST_SERVER_PLACE_ID)
    end
end)
