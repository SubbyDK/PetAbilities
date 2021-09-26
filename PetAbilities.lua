--[[
	ToDo list
        ✓ Get the addon up and running and uploaded.
        ✓ Make colors depending on we know ability or not.
        ✓ Make a check for the right version so we don't mix Classic and TBC
        Make a slash command to check what we still miss.
        Get someone to translate the few things there need that.
]]--

-- ====================================================================================================
-- =                                  Set some locals for this addon                                  =
-- ====================================================================================================

local AddonName, namespace = ...
local ABILITY_LIST = namespace.ABILITY_LIST
local LOCALIZED_CLASS, ENGLISH_CLASS = UnitClass("player");
local BEAST_TRAINING = GetSpellInfo(5149) or "Beast Training"
local PRINT_COLOR_ONE = "|cFFFFA500"
local ADDON_ADVERTISING = nil
local ADDON_ADVERTISING_COLOR_ONE = "|cFF00FF00"
local ADDON_ADVERTISING_COLOR_TWO = "|cFFFF0000"
local MISSING_RANK_SESSION = {}

-- ====================================================================================================
-- =                          Print function so all prints will be the same.                          =
-- ====================================================================================================

local function PRINT_TEXT(str)
    DEFAULT_CHAT_FRAME:AddMessage(PRINT_COLOR_ONE .. AddonName .. ":|r " .. str);
end

-- ====================================================================================================
-- =                          Check that it's the right version of the addon                          =
-- ====================================================================================================

if (select(4, GetBuildInfo()) < 20000) or (select(4, GetBuildInfo()) > 30000) then
    C_Timer.After(40, function()
        PRINT_TEXT("Your running the The Burning Crusade Era version of " .. AddonName .. ".");
        PRINT_TEXT("Please download the right version.");
    end)
    return
end

-- ====================================================================================================
-- =                  A small localization function, will be mover to seperate file.                  =
-- ====================================================================================================

if (GetLocale() == "deDE") then 
    LOCAL_RANK = "Rang"
    RANK_ERROR_1 = "have no rank, \"Rank 1\" given manually."
    RANK_ERROR_2 = "Please be aware that there may be an error with"
elseif (GetLocale() == "frFR") then 
    LOCAL_RANK = "Rang"
    RANK_ERROR_1 = "have no rank, \"Rank 1\" given manually."
    RANK_ERROR_2 = "Please be aware that there may be an error with"
elseif (GetLocale() == "esES") then 
    LOCAL_RANK = "Rango"
    RANK_ERROR_1 = "have no rank, \"Rank 1\" given manually."
    RANK_ERROR_2 = "Please be aware that there may be an error with"
elseif (GetLocale() == "esMX") then 
    LOCAL_RANK = "Rango"
    RANK_ERROR_1 = "have no rank, \"Rank 1\" given manually."
    RANK_ERROR_2 = "Please be aware that there may be an error with"
elseif (GetLocale() == "itIT") then 
    LOCAL_RANK = "Rank"
    RANK_ERROR_1 = "have no rank, \"Rank 1\" given manually."
    RANK_ERROR_2 = "Please be aware that there may be an error with"
elseif (GetLocale() == "koKR") then 
    LOCAL_RANK = "레벨"
    RANK_ERROR_1 = "have no rank, \"Rank 1\" given manually."
    RANK_ERROR_2 = "Please be aware that there may be an error with"
elseif (GetLocale() == "ptBR") then 
    LOCAL_RANK = "Grau"
    RANK_ERROR_1 = "have no rank, \"Rank 1\" given manually."
    RANK_ERROR_2 = "Please be aware that there may be an error with"
elseif (GetLocale() == "ruRU") then 
    LOCAL_RANK = "Уровень"
    RANK_ERROR_1 = "have no rank, \"Rank 1\" given manually."
    RANK_ERROR_2 = "Please be aware that there may be an error with"
elseif (GetLocale() == "zhCN") then 
    LOCAL_RANK = "等级"
    RANK_ERROR_1 = "have no rank, \"Rank 1\" given manually."
    RANK_ERROR_2 = "Please be aware that there may be an error with"
elseif (GetLocale() == "zhTW") then 
    LOCAL_RANK = "Rank"
    RANK_ERROR_1 = "have no rank, \"Rank 1\" given manually."
    RANK_ERROR_2 = "Please be aware that there may be an error with"
else
    LOCAL_RANK = "Rank"
    RANK_ERROR_1 = "have no rank, \"Rank 1\" given manually."
    RANK_ERROR_2 = "Please be aware that there may be an error with"
end

-- ====================================================================================================
-- =                             Create a frame and register some events.                             =
-- ====================================================================================================

local f = CreateFrame("Frame");
f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED");
f:RegisterEvent("PLAYER_ENTERING_WORLD");
f:RegisterEvent("ADDON_LOADED");

-- ====================================================================================================
-- =                                       The OnEvent function                                       =
-- ====================================================================================================

f:SetScript("OnEvent", function(self, event, arg1, arg2, arg3)
    -- Addon is loaded, do some stuff here.
    if event == 'ADDON_LOADED' and arg1 == AddonName then
        if not PA_PREFS then
            PA_PREFS = {}
        end
        PA_FIRST_RUN();
        -- Unregister the event, as we do not need it anymore
        f:UnregisterEvent("ADDON_LOADED");
    -- Check to see if a spell is casted successfully by our self.
    elseif (event == "UNIT_SPELLCAST_SUCCEEDED") and (arg1 == "player") then
        if (arg3 == 5149) then
            Check()
        end
    -- Check to see if we can and have made a ability scan.
    elseif (event == "PLAYER_ENTERING_WORLD") then
        C_Timer.After(16, function()
            -- Do we know Beast Training and is it first run with that spell or this addon ?
            if (IsSpellKnown(5149, false)) and (PA_PREFS.ABILITIES_FIRST_RUN == true) then
                PRINT_TEXT("You have not yet scanned your pet’s abilities, please open " .. BEAST_TRAINING .. ".");
                -- Unregister the event, as we do not need it anymore
                f:UnregisterEvent("PLAYER_ENTERING_WORLD");
            end
        end)
    end
end
)

function PA_FIRST_RUN()
    if PA_PREFS.FIRST_RUN ~= false then
        -- Create the table
        PA_PREFS = {}
        -- Set that it's the first run for the abilities addon.
        PA_PREFS.ABILITIES_FIRST_RUN = true
        -- Set first run to false so we don't run it everytime we log in.
        PA_PREFS.FIRST_RUN = false
        -- Create the table
        PA_KNOWN_ABILITIES = {}
    end
end

-- ====================================================================================================
-- =                     Scan all learned abilities and save them in the database                     =
-- ====================================================================================================

function Check()
    -- Check to see if we have "Beast Training"
    if not IsSpellKnown(5149, false) then
        return
    end
    -- Start the loop to go through all abilitys
    for i = 1, GetNumCrafts() do
        craftName, craftSubSpellName, _, _, _, _, _ = GetCraftInfo(i)        
        -- Did we get a rank ?
        if craftSubSpellName == nil then
            -- Make the name so we can use it to find the ID
            SpellName = craftName .. " (" .. LOCAL_RANK .. " 1)"
            if MISSING_RANK_SESSION[craftName] == nil then
                PRINT_TEXT("|cFFFF0000" .. "\"" .. craftName .. "\" " .. RANK_ERROR_1 ..  "|r");
                PRINT_TEXT("|cFFFF0000" .. RANK_ERROR_2 ..  " \"" .. craftName .. "\".|r");
                MISSING_RANK_SESSION[craftName] = true
            end
        else
            -- Make the name so we can use it to find the ID
            SpellName = craftName .. " (" .. craftSubSpellName .. ")"
        end
        -- Save all we find to our PA_KNOWN_ABILITIES database.
        PA_KNOWN_ABILITIES[i] = SpellName       
    end

    -- Set to false so we know that we have been running the scan at least one time.
    PA_PREFS.ABILITIES_FIRST_RUN = false

    PRINT_TEXT("|cFF00FF00" .. "Scan is completed." .. "|r");

end

-- ====================================================================================================
-- =                              Make the tooltop's so we get some info                              =
-- ====================================================================================================

GameTooltip:HookScript("OnTooltipSetUnit", function(tooltip)
    local NEW_MOB_ABILITIES = nil
    local MOB_ABILITIES = nil
    local GET_RANK = nil
    local UNIT = select(2, tooltip:GetUnit())

    if UNIT then
        local GUID = UnitGUID(UNIT) or ""
        local MOB_ID = tonumber(GUID:match("-(%d+)-%x+$"), 10)

        if MOB_ID and GUID:match("%a+") ~= "Player" then
            for KEY, VALUE in next, ABILITY_LIST do
                if KEY == MOB_ID then
                    for i, ID in ipairs(VALUE) do
                        -- If this is first run, then we get the name here.
                        if MOB_ABILITIES == nil then
                            MOB_ABILITIES = GetSpellInfo(ID);
                            GET_RANK = true
                        else
                            -- Add the rank to the ability
                            if GET_RANK == true then
                                MOB_ABILITIES = ALREADY_LEARNED(MOB_ABILITIES .. " (" .. LOCAL_RANK .. " " .. ID .. ")")
                                if NEW_MOB_ABILITIES ~= nil then
                                    NEW_MOB_ABILITIES = NEW_MOB_ABILITIES .. MOB_ABILITIES .. "|r"
                                else
                                    NEW_MOB_ABILITIES = MOB_ABILITIES .. "|r"
                                end
                                MOB_ABILITIES = ""
                                GET_RANK = false
                            -- If there is more then one ability, then we get the name here.
                            else
                                SPELL_NAME = GetSpellInfo(ID);
                                MOB_ABILITIES = MOB_ABILITIES .. SPELL_NAME
                                NEW_MOB_ABILITIES = NEW_MOB_ABILITIES .. ", "
                                GET_RANK = true
                            end
                        end
                    end
                end
            end
        -- Make a small advertising for my self. :D
        elseif MOB_ID and GUID:match("%a+") == "Player" then
            -- Is it one of my characters ?
            if (UnitGUID(UNIT) == "Player-4453-00001D86") or    -- My Hunter    (Subby)
            (UnitGUID(UNIT) == "Player-4453-013BB513") or       -- My Druid     (Awkward)
            (UnitGUID(UNIT) == "Player-4453-00008FD9") or       -- My Mage      (Sheeps)
            (UnitGUID(UNIT) == "Player-4453-013D6B61") or       -- My Rogue     (Weakly)
            (UnitGUID(UNIT) == "Player-4453-0335D2E1") or       -- My Paladin   (Subine)
            (UnitGUID(UNIT) == "Player-4453-013CA941")          -- My Priest    (Bandog)
            then
                ADDON_ADVERTISING = true
            end
        end

        -- If there is any info about the mob then put it in the tooltip.
        if NEW_MOB_ABILITIES ~= nil then
            tooltip:AddLine(" ") --blank line
            tooltip:AddLine(NEW_MOB_ABILITIES)
            tooltip:AddLine(" ") --blank line
        end
        --is there something to advertis ?
        if ADDON_ADVERTISING == true then
            tooltip:AddLine(" ") --blank line
            tooltip:AddLine(ADDON_ADVERTISING_COLOR_ONE .. "The author of:|r " .. ADDON_ADVERTISING_COLOR_TWO .. AddonName .. "|r")
            ADDON_ADVERTISING = nil
        end
    end
end)

-- ====================================================================================================
-- =         Give color to the name and rank, according to whether we have learned it or not.         =
-- ====================================================================================================

function ALREADY_LEARNED(SPELL_NAME)
    -- Check that we have learned "Beast Training" so we don't get an error.
    if not IsSpellKnown(5149, false) then
        -- Return the name and stop the function
        return(SPELL_NAME);
    end

    KNOWN_STATUS = false
    KNOWN_COLOR = "|cffa6acaf"
    UNKNOWN_COLOR = "|cff11cd39"

    -- Check if we have learned the ability.
    for i, SPELL_NAME_KNOWN in next, PA_KNOWN_ABILITIES do
        if (SPELL_NAME_KNOWN ~= nil) and (SPELL_NAME ~= nil) then
            if SPELL_NAME_KNOWN == SPELL_NAME then
                KNOWN_STATUS = true
            end
        end
    end

    -- Return the name and rank with the right color.
    if KNOWN_STATUS == true then
        return(KNOWN_COLOR .. SPELL_NAME);        
    else
        return(UNKNOWN_COLOR .. SPELL_NAME);
    end
end

-- ====================================================================================================
-- =              TEST ZONE - TEST ZONE - TEST ZONE - TEST ZONE - TEST ZONE - TEST ZONE               =
-- ====================================================================================================

--[[
local SPELL = {
  { MOB_ID = 22, SPELL_ID = 3630, RANK = 2},
  { MOB_ID = 22, SPELL_ID = 25009, RANK = 3},
  { MOB_ID = 22, SPELL_ID = 25010, RANK = 4},
}

TEST_ID = 22

function TEST_ZONE()
    for TEST_ID, TEST_NOTE in pairs(SPELL) do
        if tonumber(TEST_ID) == tonumber(MOB_ID) then
            PRINT_TEXT("Found a mob, " .. TEST_NOTE);
        else
            PRINT_TEXT("Nothing found.");
        end
    end
end

]]--
















