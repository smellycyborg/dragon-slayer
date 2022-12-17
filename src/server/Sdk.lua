--[[

- solo player game
- players move through multiple levels to defeat dragons
- dragons will have difficulty and level indicator
- dragon on death drops random sword and gold
- player can pick up dropped items by interacting
- basic fight mechanics for player
- dragons have two types of attack options
- when all dragons defeated player goes to next level

-- Todo dragon attack adjustments (dragon wingbeat attack pushes dragon off map)
-- Todo add debounce for how often dragons can damage player
-- Todo teleport player on level finish and spawn dragons after player has teleported

]]

local PlayersService = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")

local PathfindindHandler = require(script.Parent.PathfindingHandler)
local SpawnHandler = require(script.Parent.SpawnHandler)

local GOLD_PRODUCT_AMOUNT = 100
local WEAPON_DAMAGE_PRODUCT_AMOUNT = 25
local TIME_UNTIL_NEXT_ATTACK = 0.5

local Sdk = {
    _playerData = {},
    _playerDataStore = DataStoreService:GetDataStore("PlayerDataStore"),
    monsters = {},
    productIds = {
        coins = nil,  -- product id
        weaponDamage = nil, -- product id
    },
}

local function destroyMonster(target)
    local monsterIndex = table.find(Sdk.monsters, target)
    table.remove(Sdk.monsters, monsterIndex)
    target:Destroy()
end

local function destroyMonsterAndSpawnSword(target)
	local targetRootPart = target:FindFirstChild("HumanoidRootPart")
	if (not targetRootPart) then
		return
	end
	
	local targetPosition = targetRootPart.Position
    SpawnHandler.spawnSword(Assets.Swords, targetPosition)
    destroyMonster(target)
end

local function startNextLevel(player)
    Sdk:IncrementValue(player, "level", 1)

    local hasReachedMaxLevel = Sdk._playerData[player].level == Sdk.levelAmount + 1
    if (hasReachedMaxLevel) then
        warn("PLAYER HAS WON THE GAME!")
        return
    end

    -- update gameplay seconds
    Sdk.monsterAmount*=2
    Sdk.monsterDamage*=2

    SpawnHandler.spawnDragons({
        level = Sdk._playerData[player].level,
        dragons = Assets.Dragons, 
        amount = Sdk.monsterAmount, 
        monsters = Sdk.monsters, 
        gui = DragonLevelGui,
    })

    task.spawn(function()
        while task.wait() do
            PathfindindHandler(Sdk.monsters, player.Character)
        end
    end)
end

local function onSwordTouched(otherPart, player)
    local target = otherPart.Parent
    if (not target) then
        return
    end

    local targetHumanoid = target:FindFirstChild("Humanoid")
    if (not targetHumanoid) then
        return
    end

    local playerData = Sdk._playerData[player]
    local weaponDamage = playerData.weaponDamage

    print(target)

    local isMonster = table.find(Sdk.monsters, target)
    if (isMonster) then
        targetHumanoid.Health-=weaponDamage

        print("MESSAGE/Info:  Found monster..")
    end

    local monsterHasNoHealth = target.Humanoid.Health <= 0
    if (monsterHasNoHealth) then
        destroyMonsterAndSpawnSword(target)
    end
end

local function onChildAdded(child, player)
    if (child.Name ~= "Sword") then
        return
    end

    Sdk._playerData[player].isEquipped = true

    print("MESSAGE/Info:  player has equipped ", child.Name, ".")

    child.Handle.Touched:Connect(function(otherPart)
        local playerData = Sdk._playerData[player]
        local isAttacking = playerData.isAttacking
        if (not isAttacking) then
            return
        end

        onSwordTouched(otherPart, player)
    end)
end

local function onChildRemoved(child, player)
    if (child.Name ~= "Sword") then
        return
    end

    Sdk._playerData[player].isEquipped = false

    print("MESSAGE/Info:  player has unequipped ", child.Name, ".")
end

local function cloneSword(player)
    local classicSwordClone = Assets.Swords.ClassicSword:Clone()
    classicSwordClone.Name = "Sword"
    classicSwordClone.Parent = player.Backpack
end

local function onWorkspaceChildRemoved(child, player)
    if (child.Name == "Dragon") and #Sdk.monsters == 0 then
        startNextLevel(player)
    end
end

local function onCharacterAdded(character)
    local player = PlayersService:GetPlayerFromCharacter(character)
    cloneSword(player)

    local foundDragon = workspace:FindFirstChild("Dragon")
    if (not foundDragon) then
        SpawnHandler.spawnDragons({
            level = Sdk._playerData[player].level,
            dragons = Assets.Dragons, 
            amount = Sdk.monsterAmount, 
            monsters = Sdk.monsters, 
            gui = DragonLevelGui,
        })
        task.spawn(function()
            while task.wait() do
                PathfindindHandler(Sdk.monsters, player.Character)
            end
        end)
    end

    workspace.ChildRemoved:Connect(function(child)
        warn(child)
        onWorkspaceChildRemoved(child, player)
    end)

    character.ChildAdded:Connect(function(child)
        onChildAdded(child, player)
    end)

    character.ChildRemoved:Connect(function(child)
        onChildRemoved(child, player)
    end)

    local sword = character:FindFirstChild("Sword")
    if (not sword) then
        return
    end

    sword.Touched:Connect(function(otherPart)
        onSwordTouched(otherPart, player)
    end)
end

local function onCharacterRemoving(character)

end

local function createPlayerData()
    local playerData = {}

    playerData.level = 1
    playerData.coins = 0
    playerData.weaponDamage = 25
    playerData.isAttacking = false
    playerData.isEquipped = false

    return playerData
end

local function onPlayerAdded(player)
    local playerData

    local success, data = pcall(function()
        return Sdk._playerDataStore:GetAsync(player.UserId)
    end)

    if (not success) then
        playerData = createPlayerData()
    else
        if (data ~= nil) then
            playerData = data
        else
            playerData = createPlayerData()
        end
    end

    Sdk._playerData[player] = playerData

    player.CharacterAdded:Connect(onCharacterAdded)
    player.CharacterRemoving:Connect(onCharacterRemoving)
end

local function onPlayerRemoving(player)
    local playerData = Sdk._playerData[player]

    local success, err = pcall(function()
        return Sdk._playerDataStore:SetAsync(player.UserId, playerData)
    end)

    if (not success) then
        warn(err)
    end

    Sdk._playerData[player] = nil
end

local function onPromptPurchaseFinished(player, productId, purchaseSuccess)
    if (not purchaseSuccess) then
        return
    end

    local isCoins = productId == Sdk.productsIds.coins
    local isWeaponDamage = productId == Sdk.productIds.weaponDamage

    local key, amount

    if (isCoins) then
        key = "coins"
        amount = GOLD_PRODUCT_AMOUNT
    elseif (isWeaponDamage) then
        key = "weaponDamage"
        amount = WEAPON_DAMAGE_PRODUCT_AMOUNT
    end

    Sdk:IncrementValue(player, key, amount)
end

local function onPromptPurchaseEvent(player, product)
    local COINS_AMOUNT = 100
    local WEAPON_DAMAGE_AMOUNT = 5
    local playerData = Sdk._playerData[player]
    local coins = playerData.coins

    local hasCoinsAndIsWeaponDamage = coins >= COINS_AMOUNT and product == "weaponDamage"
    if (hasCoinsAndIsWeaponDamage) then
        Sdk._playerData[player].coins-=COINS_AMOUNT
        Sdk:IncrementValue(player, product, WEAPON_DAMAGE_AMOUNT)
    else
        local productId = Sdk.productIds[product]
        MarketplaceService:PromptProductPurchase(player, productId)
    end
end

local function checkActionStatus(player)
    local playerData = Sdk._playerData[player]
    local isEquipped = playerData.isEquipped
    if (not isEquipped) then
        return false
    end

    local isAttacking = playerData.isAttacking
    if (isAttacking) then
        return false
    end

    return true
end

local function onPlayerIsChargingEvent(player)
    local playerData = Sdk._playerData[player]
    
    local canAttack = checkActionStatus(player)
    if (not canAttack) then
        return
    end

    local Sword = player.Character:FindFirstChild("Sword")
    if (not Sword) then
        return
    end

    local character = player.Character
    local humanoid = character.Humanoid
    local animator = humanoid.Animator

    local chargingAnimation = Sword.Animations.ChargeAnim
    chargingAnimationLoader = animator:LoadAnimation(chargingAnimation)

    chargingAnimationLoader:Play()
end

local function onPlayerIsAttackingEvent(player)
    local playerData = Sdk._playerData[player]

    local canAttack = checkActionStatus(player)
    if (not canAttack) then
        return
    end

    local Sword = player.Character:FindFirstChild("Sword")
    if (not Sword) then
        return
    end

    local character = player.Character
    local humanoid = character.Humanoid
    local animator = humanoid.Animator

    local attackAnimations = {
        [1] = Sword.Animations.SlashAnim,
        [2] = Sword.Animations.StabAnim,
    }

    local randomIndex = math.random(1, #attackAnimations)
    local randomAttackAnimation = attackAnimations[randomIndex]
    local attackAnimationLoader = animator:LoadAnimation(randomAttackAnimation)

    chargingAnimationLoader:Stop()
    attackAnimationLoader:Play()

    Sdk._playerData[player].isAttacking = true

    print("MESSAGE/Info:  Player is attacking.")

    task.wait(TIME_UNTIL_NEXT_ATTACK)

    Sdk._playerData[player].isAttacking = false
end

local function onDealDamageFunction(player, target)
    local playerData = Sdk._playerData[player]
    local weaponDamage = playerData.weaponDamage

    local monster = Sdk.monsters[target]
    monster.health-=weaponDamage

    return weaponDamage
end

function Sdk.init(options)

    -- gameplay options
    Sdk.levelAmount = options.levelAmount
    Sdk.monsterAmount = options.monsterAmount
    Sdk.monsterHealth = options.monsterHealth
    Sdk.monsterDamage = options.monsterDamage

    -- remotes
    local RemoteEvents = Instance.new("Folder", ReplicatedStorage)
    RemoteEvents.Name = "RemoteEvents"
    local RemoteFunctions = Instance.new("Folder", ReplicatedStorage)
    RemoteFunctions.Name = "RemoteFunctions"

    local promptPurchaseEvent = Instance.new("RemoteEvent", RemoteEvents)
    promptPurchaseEvent.Name = "PromptPurchaseEvent"
    local playerIsChargingEvent = Instance.new("RemoteEvent", RemoteEvents)
    playerIsChargingEvent.Name = "PlayerIsChargingEvent"
    local playerIsAttackingEvent = Instance.new("RemoteEvent", RemoteEvents)
    playerIsAttackingEvent.Name = "PlayerIsAttackingEvent"
    local dealDamageFunction = Instance.new("RemoteFunction", RemoteFunctions)
    dealDamageFunction.Name = "DealDamageFunction"

    -- setting locations
    Assets = script.Parent.Assets
    Assets.Parent = ReplicatedStorage
    local AttackHandler = script.Parent.AttackHandler
    AttackHandler.Parent = StarterPlayer.StarterCharacterScripts
    local ShopGuiHandler = script.Parent.ShopGuiHandler
    ShopGuiHandler.Parent = StarterPlayer.StarterCharacterScripts
    local ShopGui = script.Parent.ShopGui
    ShopGui.Parent = StarterGui
    DragonLevelGui = script.Parent.DragonLevelGui
    DragonLevelGui.Parent = ReplicatedStorage

    -- bindings
    promptPurchaseEvent.OnServerEvent:Connect(onPromptPurchaseEvent)
    playerIsChargingEvent.OnServerEvent:Connect(onPlayerIsChargingEvent)
    playerIsAttackingEvent.OnServerEvent:Connect(onPlayerIsAttackingEvent)
    dealDamageFunction.OnServerInvoke = onDealDamageFunction
    MarketplaceService.PromptPurchaseFinished:Connect(onPromptPurchaseFinished)
    PlayersService.PlayerAdded:Connect(onPlayerAdded)
    PlayersService.PlayerRemoving:Connect(onPlayerRemoving)

end

function Sdk:IncrementValue(player, key, amount)
    self._playerData[player][key]+=amount
end

return Sdk