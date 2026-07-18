local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

const assets = require("@pkg/assets")

const vide = require("@pkg/vide")
const create = vide.create
const source = vide.source
const spring = vide.spring
const root = vide.root

const Remotes = ReplicatedStorage:WaitForChild("remotes")
const increaseScore = Remotes:WaitForChild("increaseScore")

const localPlayer = Players.LocalPlayer
const playerGui = localPlayer.PlayerGui

const function app()
    const score = source(0)
    const isHovered = source(false)
    const isHeldDown = source(false)

    create "ScreenGui" {
        Parent = playerGui,

        ResetOnSpawn = false,
        IgnoreGuiInset = true,

        create "Frame" {
            Size = UDim2.fromScale(1, 1),

            BackgroundColor3 = Color3.new(1, 1, 1),

            create "ImageButton" {
                MouseEnter = function()
                    isHovered(true)
                end,

                MouseLeave = function()
                    isHovered(false)
                end,

                MouseButton1Down = function()
                    isHeldDown(true)
                    score(score() + 1)
                    increaseScore:FireServer()
                end,

                MouseButton1Up = function()
                    isHeldDown(false)
                end,

                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromScale(0.2, 0.2),

                BackgroundTransparency = 1,

                SizeConstraint = Enum.SizeConstraint.RelativeYY,

                Image = assets["osaka_bird.png"],

                create("UIScale", {
                    Scale = spring(function()
                        return if isHeldDown() then 1 elseif isHovered() then 1.05 else 1
                    end, 0.25),
                }),

                create("UIStroke", {
                    Thickness = 2,

                    Color = Color3.fromRGB(127, 127, 127),
                    Transparency = 0.5,
                }),
            },

            create "TextLabel" {
                AnchorPoint = Vector2.new(0.5, 0),
                Position = UDim2.fromScale(0.5, 0.65),
                Size = UDim2.fromScale(0.3, 0.025),

                BackgroundTransparency = 1,

                Text = function()
                    return `Score: {score()}`
                end,
                TextColor3 = Color3.new(1, 1, 1),
                FontFace = Font.new("rbxassetid://12187365364"),
                TextScaled = true,
            },

            create "UIGradient" {
                Color = ColorSequence.new(Color3.fromHex("0f0f0f"), Color3.fromHex("171717")),
                Rotation = 90,
            },
        },
    }
end

root(app)
