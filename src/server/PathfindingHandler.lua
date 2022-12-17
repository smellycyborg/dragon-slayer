local PlayersService = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")

local MONVE_TO_FINISHED_WAIT_TIME = 2
local TIME_UNTIL_NEXT_ATTACK = 3

local wingBeatAnimationId = "rbxassetid://11838906161"
local fireBreathAnimationId = "rbxassetid://11838978666"

local wingBeatAnimation = Instance.new("Animation")
wingBeatAnimation.AnimationId = wingBeatAnimationId
local fireBreathAnimation = Instance.new("Animation")
fireBreathAnimation.AnimationId = fireBreathAnimationId

local monsterAttackAnimatons = {
    [1] = wingBeatAnimation,
    [2] = fireBreathAnimation,
}

local monstersAttacking = {}

local function onMonsterPartTouch(otherPart)
    local character = otherPart.Parent
    local player = PlayersService:GetPlayerFromCharacter(character)
    if (not player) then
        return
    end

    local humanoid = character:FindFirstChild("Humanoid")
    if (not humanoid) then
        return
    end

    humanoid.Health-=1
end

local function goThroughMonsterParts(monster)
    for _, part in pairs(monster:GetChildren()) do 
        if part:IsA("Part") then
            part.Touched:Connect(onMonsterPartTouch)
        end
    end
end

local function monsterAttack(monster)
    local monsterHumanoid = monster:FindFirstChild("Humanoid")
    if (not monsterHumanoid) then
        return
    end

    local animator = monsterHumanoid.Animator

    local randomIndex = math.random(1, #monsterAttackAnimatons)
    local randomAnimation = monsterAttackAnimatons[randomIndex]

    local wingBeatAnimationLoader = animator:LoadAnimation(wingBeatAnimation)
    wingBeatAnimationLoader:Play()
end

local function monsterAttackHandler(monster)
    local isAttacking = table.find(monstersAttacking, monster)
    if (isAttacking) then 
        return
    end

    table.insert(monstersAttacking, monster)

    monsterAttack(monster)
    goThroughMonsterParts(monster)

    task.wait(TIME_UNTIL_NEXT_ATTACK)

    local monsterIndex = table.find(monstersAttacking, monster)
    table.remove(monstersAttacking, monsterIndex)
end

local function handlePathfinding(monster, character)
    if (not character) then
        return
    end

    local monsterHumanoid = monster:FindFirstChild("Humanoid")
    if (not monsterHumanoid) then
        return
    end

    local monsterRootPart = monster:FindFirstChild("HumanoidRootPart")
    if not monsterRootPart then
        return
    end

    local path = PathfindingService:CreatePath()
    path:ComputeAsync(monsterRootPart.Position, character.PrimaryPart.Position)

    local waypoints = path:GetWaypoints()

    for _, waypoint in pairs(waypoints) do
        local ball = Instance.new("Part")
        ball.Shape = "Ball"
        ball.Material = "Neon"
        ball.Size = Vector3.new(0.6, 0.6, 0.6)
        ball.Position = waypoint.Position
        ball.Anchored = true
        ball.CanCollide = false
        ball.Parent = game.Workspace

        monsterHumanoid:MoveTo(waypoint.Position)

        monsterHumanoid.MoveToFinished:Wait(MONVE_TO_FINISHED_WAIT_TIME)
    end
end

function PathfindingHandler(monsters, character)
    for _, monster in pairs(monsters) do
        task.spawn(function()
            handlePathfinding(monster, character)
            monsterAttackHandler(monster)
        end)
    end
end

return PathfindingHandler