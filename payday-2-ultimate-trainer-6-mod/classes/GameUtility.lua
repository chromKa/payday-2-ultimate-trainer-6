UT.GameUtility = {}

function UT.GameUtility:idString(id)
    return Idstring(id)
end

function UT.GameUtility:getGameState()
    return game_state_machine:current_state_name()
end

function UT.GameUtility:isInBootup()
    return UT.GameUtility:getGameState() == "bootup"
end

function UT.GameUtility:isInMainMenu()
    return UT.GameUtility:getGameState() == "menu_main"
end

function UT.GameUtility:isInGame()
    return UT.Utility:toBoolean(GameStateFilters.any_ingame[UT.GameUtility:getGameState()])
end

function UT.GameUtility:isInHeist()
    local gameState = UT.GameUtility:getGameState()
    return UT.Utility:toBoolean(Global.game_settings.is_playing and not (not GameStateFilters.waiting_for_respawn[gameState] and not GameStateFilters.waiting_for_spawn_allowed[gameState] and not UT.GameUtility:isPlayerUnitAlive()))
end

function UT.GameUtility:isPlaying()
    local gameState = UT.GameUtility:getGameState()
    return UT.Utility:toBoolean(UT.GameUtility:isInHeist() and not GameStateFilters.waiting_for_respawn[gameState] and not GameStateFilters.waiting_for_spawn_allowed[gameState])
end

function UT.GameUtility:isInCustody()
    return UT.Utility:toBoolean(GameStateFilters.waiting_for_respawn[UT.GameUtility:getGameState()])
end

function UT.GameUtility:isDriving()
    return UT.GameUtility:getGameState() == "ingame_driving"
end

function UT.GameUtility:isAtEndGame()
    local endGameStates = { "victoryscreen", "gameoverscreen", "disconnected", "server_left", "kicked" }
    return UT.Utility:inTable(UT.GameUtility:getGameState(), endGameStates)
end

function UT.GameUtility:isServer()
    return Network:is_server()
end

function UT.GameUtility:isInSinglePlayer()
    return Global.game_settings.single_player
end

function UT.GameUtility:isTeamAIEnabled()
    return managers.groupai and managers.groupai:state():team_ai_enabled() or false
end

function UT.GameUtility:getPlayerUnit()
    return managers.player:player_unit()
end

function UT.GameUtility:getPlayerPosition()
    return UT.GameUtility:getPlayerUnit():position()
end

function UT.GameUtility:getPlayerRotation()
    return UT.GameUtility:getPlayerUnit():rotation()
end

function UT.GameUtility:getPlayerCamera()
    return UT.GameUtility:getPlayerUnit():camera()
end

function UT.GameUtility:getPlayerCameraPosition()
    return UT.GameUtility:getPlayerCamera():position()
end

function UT.GameUtility:getPlayerCameraRotation()
    return UT.GameUtility:getPlayerCamera():rotation()
end

function UT.GameUtility:getPlayerCameraYawRotation()
    return Rotation(UT.GameUtility:getPlayerCameraRotation():yaw(), 0, 0)
end

function UT.GameUtility:getPlayerCameraForward()
    return UT.GameUtility:getPlayerCamera():forward()
end

function UT.GameUtility:getCrosshairRay()
    return Utils:GetCrosshairRay()
end

function UT.GameUtility:getCrosshairRayPosition()
    local crosshairRay = UT.GameUtility:getCrosshairRay()
    if not crosshairRay then
        return nil
    end
    return crosshairRay.position
end

function UT.GameUtility:isPlayerUsingZipline()
    return UT.Utility:toBoolean(UT.GameUtility:getPlayerUnit():movement():zipline_unit())
end

function UT.GameUtility:isUnitAlive(unit)
    return alive(unit)
end

function UT.GameUtility:isPlayerUnitAlive()
    local playerUnit = UT.GameUtility:getPlayerUnit()
    if not playerUnit then
        return false
    end
    return UT.GameUtility:isUnitAlive(playerUnit)
end

function UT.GameUtility:isUnitLoaded(unitId)
    local typeId = UT.GameUtility:idString("unit")
    return PackageManager:has(typeId, unitId)
end

function UT.GameUtility:spawnUnit(unitId, position, rotation)
    if not UT.GameUtility:isUnitLoaded(unitId) then
        return nil
    end
    return World:spawn_unit(unitId, position, rotation)
end

function UT.GameUtility:deleteUnit(unit)
    if not UT.GameUtility:isUnitAlive(unit) then
        return nil
    end
    World:delete_unit(unit)
    managers.network:session():send_to_peers_synched("remove_unit", unit)
end

function UT.GameUtility:killUnit(unit)
    if not UT.GameUtility:isUnitAlive(unit) then
        return nil
    end
    unit:character_damage():damage_explosion({
        variant = "explosion",
        damage = UT.maxInteger,
        col_ray = {
            ray = Vector3(1, 0, 0),
            position = unit:position()
        }
    })
end

function UT.GameUtility:setUnitTeam(unit, team)
    if not UT.GameUtility:isUnitAlive(unit) then
        return nil
    end
    local teamId = tweak_data.levels:get_default_team_ID(team)
    local teamData = managers.groupai:state():team_data(teamId)
    unit:movement():set_team(teamData)
end

function UT.GameUtility:convertEnemy(unit)
    if not UT.GameUtility:isUnitAlive(unit) then
        return nil
    end
    managers.groupai:state():convert_hostage_to_criminal(unit)
    managers.groupai:state():sync_converted_enemy(unit)
    unit:contour():add("friendly", true)
end

function UT.GameUtility:getLocalPeerId()
    return managers.network:session():local_peer():id()
end

function UT.GameUtility:refreshPlayerProfileGUI()
    managers.menu_component:refresh_player_profile_gui()
end

function UT.GameUtility:saveProgress()
    managers.savefile:save_progress()
end

function UT.GameUtility:getPlayerState()
    return managers.player:current_state()
end

function UT.GameUtility:setPlayerState(state)
    managers.player:set_player_state(state)
end

function UT.GameUtility:teleportPlayer(position, rotation)
    managers.player:warp_to(position, rotation)
end

function UT.GameUtility:interactFromTable(table)
    if not table then
        return
    end

    local isMaskOff = UT.GameUtility:getPlayerState() == "mask_off"

    if isMaskOff then
        UT.GameUtility:setPlayerState("clean")
    end

    local playerUnit = UT.GameUtility:getPlayerUnit()
    local units = UT.Utility:deepClone(managers.interaction._interactive_units)
    for index, unit in pairs(units) do
        if not UT.GameUtility:isUnitAlive(unit) then
            goto continue
        end

        local key = unit:name():key()
        if UT.Utility:inTable(key, table) then
            unit:interaction():interact(playerUnit)
        end

        ::continue::
    end

    if isMaskOff then
        UT.GameUtility:setPlayerState("mask_off")
    end
end

function UT.GameUtility:getLocalizationText(id)
    return managers.localization:text(id)
end

-- LocalizationManager:exists() crashes the game sometimes
function UT.GameUtility:localizationExists(id)
    local text = UT.GameUtility:getLocalizationText(id)
    return not UT.Utility:isEmptyString(text) and not UT.Utility:stringStartsWith(text, "ERROR: ")
end
