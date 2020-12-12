local _, ns = ...

local destinations = {
    orgrimmar = {
        { -- Cloak of Coordination
            itemId = 65274,
            inventorySlot = INVSLOT_BACK,
            spellId = 89158
        },
        { -- Wrap of Unity
            itemId = 63207,
            inventorySlot = INVSLOT_BACK,
            spellId = 89158
        },
        { -- Shroud of Cooperation
            itemId = 63353,
            inventorySlot = INVSLOT_BACK,
            spellId = 89158
        }
    },
}

local color = '|cff42f58d'
local reset = '|r'
local equipping = nil
local readyToCast = nil
local casting = nil
local frame = CreateFrame('Frame', 'HearthCloak', UIParent, 'BackdropTemplate')

do
    local width = 150
    local fontHeight = 18

    frame:SetWidth(width)
    frame:SetHeight(70)
    frame:SetPoint('CENTER')
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag('LeftButton')
    frame:SetScript('OnDragStart', frame.StartMoving)
    frame:SetScript('OnDragStop', frame.StopMovingOrSizing)
    frame:SetBackdrop({ 
        bgFile = 'Interface\\DialogFrame\\UI-DialogBox-Background', 
        tile = true,
        tileSize = 32,
        insets = { left = -5, right = -5, top = -5, bottom = -5 }
    })

    frame.title = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    frame.title:SetText(color .. 'HearthCloak: ')
    frame.title:SetPoint('TOPLEFT', frame, 'TOPLEFT')
    frame.title:SetWidth(width)
    frame.title:SetHeight(fontHeight)

    frame.teleport = CreateFrame('Button', 'hearthCloakTeleport', frame, 'SecureActionButtonTemplate,ActionButtonTemplate')

    frame.teleport:SetAttribute('type', 'item')
    frame.teleport:SetSize(50, 50)
    frame.teleport:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT')
    frame.teleport:SetScript('PreClick', function()
        frame:Hide()
    end)
    ActionButton_ShowOverlayGlow(frame.teleport)
    frame:Hide()
end

local function log(msg)
    print(color .. 'HearthCloak: ' .. msg .. reset)
end

local function prepareFrame(data)
    readyToCast = data
    frame.title:SetText(color .. 'HearthCloak: ' .. reset .. data.destination)
    frame.teleport:SetAttribute('item', data.inventorySlot)
    frame.teleport.icon:SetTexture(data.texture)
    frame:Show()
end

local function findInInventory(inventorySlot, searchItemId, cooldowns)
    local itemId = GetInventoryItemID('player', inventorySlot);
    if itemId == searchItemId then
        local itemLink = GetInventoryItemLink('player', inventorySlot)
        local now = time()
        local cooldownStart, cooldownDuration, cooldown = GetInventoryItemCooldown('player', inventorySlot)
        if cooldown == 1 and cooldownStart == 0 then
            return {
                inventorySlot = inventorySlot,
                texture = GetInventoryItemTexture('player', inventorySlot),
                link = itemLink
            }
        else
            cooldowns[#cooldowns + 1] = {
                link = itemLink,
                remaining = (cooldownStart + cooldownDuration) - now
            }
        end
    end
end

local function findInBags(searchItemId, cooldowns)
    for bag=0, NUM_BAG_SLOTS do
        for slot=1, GetContainerNumSlots(bag) do
            local itemId = GetContainerItemID(bag, slot)
            if itemId == searchItemId then
                local texture, _, _, _, _, _, itemLink = GetContainerItemInfo(bag, slot)
                local now = time()
                local cooldownStart, cooldownDuration, cooldown = GetContainerItemCooldown(bag, slot)
                if cooldown == 1 and cooldownStart == 0 then
                    return {
                        bag = bag,
                        slot = slot,
                        texture = texture,
                        link = itemLink
                    }
                else
                    cooldowns[#cooldowns + 1] = {
                        link = itemLink,
                        remaining = (cooldownStart + cooldownDuration) - now
                    }
                end
            end
        end
    end

    return nil
end

local function port(msg)
    local destination
    if not msg or msg == '' then
        destination = nil
    else
        destination = destinations[msg]
    end

    if destination == nil then
        local keys = ''
        for key, _ in pairs(destinations) do
            if keys ~= '' then
                keys = keys .. ', '
            end
            keys = keys .. key
        end
        log('usage: /hearthcloak [' .. keys .. ']')
        return
    end

    local found = nil
    local cooldowns = {}

    for _, item in pairs(destination) do
        if item.inventorySlot ~= nil then
            found = findInInventory(item.inventorySlot, item.itemId, cooldowns)
            if found ~= nil then
                found.itemId = item.itemId
                found.spellId = item.spellId
                break
            end
        end
    end

    if found == nil then
        for _, item in pairs(destination) do
            found = findInBags(item.itemId, cooldowns)
            if found ~= nil then
                found.itemId = item.itemId
                found.spellId = item.spellId
                found.inventorySlot = item.inventorySlot
                break
            end
        end
    end

    if found == nil then
        if #cooldowns > 0 then
            log('All items on cooldown')
        else
            log('No items found')
        end
    end

    found.destination = msg

    if found.bag ~= nil and found.inventorySlot ~= nil and GetInventoryItemID('player', found.inventorySlot) ~= nil then
        found.replaceLink = GetInventoryItemLink('player', found.inventorySlot)
    end

    log('Teleporting to ' .. reset .. found.destination .. color .. ' with ' .. found.link)
    if found.replaceLink ~= nil then
        log('Temporarily replacing ' .. found.replaceLink)
    end

    if found.bag ~= nil then
        equipping = found
        ClearCursor()
        PickupContainerItem(found.bag, found.slot)
        PickupInventoryItem(found.inventorySlot)
    else
        prepareFrame(found)
    end
end

local events = {};

events.ITEM_LOCK_CHANGED = function(bagOrSlotId, slotId)
    if equipping == nil then
        return
    end

    if slotId == nil and bagOrSlotId == equipping.inventorySlot and not IsInventoryItemLocked(equipping.inventorySlot) and GetInventoryItemID("player", equipping.inventorySlot) == equipping.itemId then
        prepareFrame(equipping)
        equipping = nil
    end
end

events.UNIT_SPELLCAST_START = function(target, castId, spellId)
    if readyToCast == nil or target ~= 'player' then
        return
    end


    if readyToCast.spellId == spellId then
        readyToCast.castId = castId
        casting = readyToCast
        readyToCast = nil
    end
end

events.UNIT_SPELLCAST_INTERRUPTED = function(target, castId, spellId)
    if casting == nil or target ~= 'player' or casting.castId ~= castId then
        return
    end

    prepareFrame(casting)
    casting = nil
end

events.UNIT_SPELLCAST_SUCCEEDED = function(target, castId, spellId)
    if casting == nil or target ~= 'player' or casting.castId ~= castId then
        return
    end

    if casting.bag then
        print('restore item here')
    end
end

frame:SetScript('OnEvent', function(self, event, ...)
    local handler = events[event]
    if handler then
        handler(...)
    end
end)
frame:RegisterEvent('ITEM_LOCK_CHANGED')
frame:RegisterEvent('UNIT_SPELLCAST_START')
frame:RegisterEvent('UNIT_SPELLCAST_INTERRUPTED')
frame:RegisterEvent('UNIT_SPELLCAST_SUCCEEDED')

SlashCmdList.HEARTHCLOAK = port
SLASH_HEARTHCLOAK1 = '/hearthcloak'

