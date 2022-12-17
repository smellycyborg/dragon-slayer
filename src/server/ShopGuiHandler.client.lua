local PlayersService = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local PromptPurchaseEvent = RemoteEvents.PromptPurchaseEvent

local player = PlayersService.LocalPlayer
local playerGui = player.PlayerGui

local ShopGui = playerGui:WaitForChild("ShopGui")
local ShopBtnsHolder = ShopGui.ShopBtnsHolder
ShopBtnsHolder.Visible = false
local OpenShopBtn = ShopGui.TextButton

local function openShop()
    ShopBtnsHolder.Visible = not ShopBtnsHolder.Visible
end

for _, btn in pairs(ShopBtnsHolder:GetChildren()) do
    local isBtn = btn:IsA("TextButton")
    if (not isBtn) then
        continue
    end

    local product
    local isCoinsBtn = btn.Name == "CoinsBtn"
    local isWeaponDamageBtn = btn.Name == "WeaponDamageBtn"
    
    if (isCoinsBtn) then
        product = "coins"
    elseif (isWeaponDamageBtn) then
        product = "weaponDamage"
    end

    btn.MouseButton1Up:Connect(function()
        PromptPurchaseEvent:FireServer(product)
    end)
end

OpenShopBtn.MouseButton1Up:Connect(openShop)