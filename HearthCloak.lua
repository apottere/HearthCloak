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

local function log(msg)
    print(color .. 'HearthCloak: ' .. msg .. reset)
end

local function findInInventory(inventorySlot, searchItemId, cooldowns)
    local itemId = GetInventoryItemID("player", inventorySlot);
    if itemId == searchItemId then
        local itemLink = GetInventoryItemLink("player", inventorySlot)
        local now = time()
        local cooldownStart, cooldownDuration, cooldown = GetInventoryItemCooldown("player", inventorySlot)
        if cooldown == 1 and cooldownStart == 0 then
            return {
                inventorySlot = inventorySlot,
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
                local itemLink = GetContainerItemLink(bag, slot)
                local now = time()
                local cooldownStart, cooldownDuration, cooldown = GetContainerItemCooldown(bag, slot)
                if cooldown == 1 and cooldownStart == 0 then
                    return {
                        bag = bag,
                        slot = slot,
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
                keys = keys .. ", "
            end
            keys = keys .. key
        end
        log('usage: /hearthcloak [' .. keys .. ']')
        return
    end

    local candidate = nil
    local cooldowns = {}

    for _, item in pairs(destination) do
        if item['inventorySlot'] ~= nil then
            candidate = findInInventory(item['inventorySlot'], item['itemId'], cooldowns)
            if candidate ~= nil then
                break
            end
        end
    end

    if candidate == nil then
        for _, item in pairs(destination) do
            candidate = findInBags(item['itemId'], cooldowns)
            if candidate ~= nil then
                candidate['inventorySlot'] = item['inventorySlot']
                break
            end
        end
    end

    if candidate == nil then
        if #cooldowns > 0 then
            log('All items on cooldown')
        else
            log('No items found')
        end
    end

    if candidate['bag'] ~= nil and candidate['inventorySlot'] ~= nil and GetInventoryItemID("player", candidate['inventorySlot']) ~= nil then
        candidate['replaceLink'] = GetInventoryItemLink("player", candidate['inventorySlot'])
    end

    log('Teleporting to ' .. reset .. msg .. color .. ' with ' .. candidate['link'])
    if candidate['replaceLink'] ~= nil then
        log('Temporarily replacing ' .. candidate['replaceLink'])
    end

    if candidate['bag'] ~= nil then
        UseContainerItem(candidate['bag'], candidate['slot'], "player")
    end

    UseInventoryItem(candidate['inventorySlot'])
end

local events = {};

events.UNIT_SPELLCAST_SUCCEEDED = function(target, castId, spellId)
    if spellId == teleportOrgrimarId then
        print("target: " .. target .. ", castId: " .. castId .. ", spellId: " .. spellId)
    end
end

local frame = CreateFrame("Frame", "HearthCloak", UIParent)
frame:SetScript("OnEvent", function(self, event, ...)
    local handler = events[event]
    if handler then
        handler(...)
    end
end)
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

SlashCmdList.HEARTHCLOAK = port
SLASH_HEARTHCLOAK1 = '/hearthcloak'

