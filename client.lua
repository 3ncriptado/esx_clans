local ESX = exports['es_extended']:getSharedObject()

-- Variables locales
local clanId = nil
local clanName = nil
local isLeader = false
local clanMembers = {}
local showHUD = Config.HUD.enabled
local clanBlips = {}
local clanBaseBlip = nil
local clanBase = nil
local isRefreshingMembers = false
local pendingMembersRefresh = false
local isUpdatingBlips = false

-- Comandos
RegisterCommand('openclanmenu', function()
    OpenClanMenu()
end, false)

-- RegisterKeyMapping('clan', 'Abrir menú de clan', 'keyboard', 'F7') -- Tecla F7 para abrir el menú

-- Funciones de utilidad

-- Funciones para el HUD NUI

local function UpdateNUIHUD()
    if not clanId or not showHUD then return end
    
    SendNUIMessage({
        action = 'updateClan',
        clanName = clanName,
        members = clanMembers
    })
    
    SendNUIMessage({
        action = 'toggleVisibility',
        show = showHUD
    })
end

local function GetPlayerByIdentifier(identifier)
    for _, member in ipairs(clanMembers) do
        if member.identifier == identifier then
            return member
        end
    end
    return nil
end

-- Funciones principales
local function RefreshClanMembers()
    if not clanId then return end

    if isRefreshingMembers then
        pendingMembersRefresh = true
        return
    end

    isRefreshingMembers = true

    ESX.TriggerServerCallback('esx_clans:getClanMembers', function(members)
        if members then
            clanMembers = members

            -- Actualizar el HUD NUI si está habilitado
            if showHUD then
                UpdateNUIHUD()
            end
        end

        isRefreshingMembers = false

        if pendingMembersRefresh then
            pendingMembersRefresh = false
            RefreshClanMembers()
        end
    end)
end

local function ToggleHUD()
    showHUD = not showHUD
    
    lib.notify({
        title = 'Clan',
        description = showHUD and 'HUD activado' or 'HUD desactivado',
        type = 'info'
    })
    
    -- Actualizar visibilidad del HUD NUI
    SendNUIMessage({
        action = 'toggleVisibility',
        show = showHUD
    })
end

local function CreateClanBaseBlip(coords)
    -- Eliminar blip anterior si existe
    if clanBaseBlip and DoesBlipExist(clanBaseBlip) then
        RemoveBlip(clanBaseBlip)
    end
    
    -- Crear nuevo blip para la base del clan
    clanBaseBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    
    -- Configurar el blip
    SetBlipSprite(clanBaseBlip, Config.BaseBlip.sprite)
    SetBlipDisplay(clanBaseBlip, 4)
    SetBlipScale(clanBaseBlip, Config.BaseBlip.scale)
    SetBlipColour(clanBaseBlip, Config.BaseBlip.color)
    SetBlipAsShortRange(clanBaseBlip, false)
    
    -- Añadir etiqueta
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(Config.BaseBlip.label .. ": " .. (clanName or ""))
    EndTextCommandSetBlipName(clanBaseBlip)
    
    -- Guardar las coordenadas
    clanBase = coords
end

local function RemoveClanBaseBlip()
    if clanBaseBlip and DoesBlipExist(clanBaseBlip) then
        RemoveBlip(clanBaseBlip)
        clanBaseBlip = nil
        clanBase = nil
    end
end

local function RemoveAllClanBlips()
    for _, blip in pairs(clanBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    clanBlips = {}
end

local function UpdateClanMembersBlips()
    if not clanId or isUpdatingBlips then return end

    -- Eliminar blips antiguos
    RemoveAllClanBlips()

    isUpdatingBlips = true

    -- Obtener ubicaciones de los miembros
    ESX.TriggerServerCallback('esx_clans:getClanMembersLocations', function(locations)
        for name, coords in pairs(locations) do
            local blip = AddBlipForCoord(coords.x, coords.y, coords.z)

            SetBlipSprite(blip, 1)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, 0.7)
            SetBlipColour(blip, 2)
            SetBlipAsShortRange(blip, false)
            
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(name)
            EndTextCommandSetBlipName(blip)

            table.insert(clanBlips, blip)
        end

        isUpdatingBlips = false
    end)
end

-- Menú de Clanes con ox_lib
function OpenClanMenu()
    ESX.TriggerServerCallback('esx_clans:getPlayerClan', function(clan)
        if clan then
            clanId = clan.id
            clanName = clan.name
            isLeader = clan.isLeader
            RefreshClanMembers()
            OpenMemberClanMenu()
        else
            OpenNoClanMenu()
        end
    end)
end

function OpenNoClanMenu()
    lib.registerContext({
        id = 'clan_menu',
        title = Config.Locale['clan_menu_title'],
        options = {
            {
                title = Config.Locale['create_clan'],
                description = 'Crea tu propio clan',
                icon = 'users',
                onSelect = function()
                    local input = lib.inputDialog(Config.Locale['enter_clan_name'], {
                        { type = 'input', label = 'Nombre del Clan', required = true }
                    })
                    
                    if input and input[1] and input[1]:len() > 0 then
                        TriggerServerEvent('esx_clans:createClan', input[1])
                    end
                end
            }
        }
    })
    
    lib.showContext('clan_menu')
end

function OpenMemberClanMenu()
    local options = {}
    
    if isLeader then
        table.insert(options, {
            title = Config.Locale['invite_player'],
            description = 'Invita a un jugador cercano a unirse a tu clan',
            icon = 'user-plus',
            onSelect = function()
                ESX.TriggerServerCallback('esx_clans:getNearbyPlayers', function(players)
                    if #players == 0 then
                        lib.notify({
                            title = 'Clan',
                            description = Config.Locale['no_players_nearby'],
                            type = 'error'
                        })
                        return
                    end
                    
                    local inviteOptions = {}
                    
                    for _, player in ipairs(players) do
                        table.insert(inviteOptions, {
                            title = player.name,
                            description = 'ID: ' .. player.id,
                            onSelect = function()
                                TriggerServerEvent('esx_clans:invitePlayer', player.id)
                            end
                        })
                    end
                    
                    lib.registerContext({
                        id = 'invite_menu',
                        title = Config.Locale['invite_player'],
                        menu = 'clan_menu',
                        options = inviteOptions
                    })
                    
                    lib.showContext('invite_menu')
                end, Config.InviteDistance)
            end
        })
        
        table.insert(options, {
            title = Config.Locale['kick_member'],
            description = 'Expulsa a un miembro del clan',
            icon = 'user-minus',
            onSelect = function()
                local kickOptions = {}
                
                for _, member in ipairs(clanMembers) do
                    if not member.isLeader then
                        table.insert(kickOptions, {
                            title = member.name,
                            description = 'Expulsar del clan',
                            onSelect = function()
                                TriggerServerEvent('esx_clans:kickMember', member.identifier)
                            end
                        })
                    end
                end
                
                if #kickOptions == 0 then
                    table.insert(kickOptions, {
                        title = 'No hay miembros para expulsar',
                        description = 'Eres el único miembro del clan'
                    })
                end
                
                lib.registerContext({
                    id = 'kick_menu',
                    title = Config.Locale['kick_member'],
                    menu = 'clan_menu',
                    options = kickOptions
                })
                
                lib.showContext('kick_menu')
            end
        })
        
        -- Opción para marcar la base del clan
        table.insert(options, {
            title = 'Marcar BASE',
            description = 'Marca tu ubicación actual como la base del clan',
            icon = 'map-marker-alt',
            onSelect = function()
                local alert = lib.alertDialog({
                    header = 'Marcar BASE',
                    content = '¿Quieres marcar tu ubicación actual como la base del clan?\nEsta ubicación será visible en el mapa para todos los miembros del clan.',
                    centered = true,
                    cancel = true
                })
                
                if alert == 'confirm' then
                    local coords = GetEntityCoords(PlayerPedId())
                    TriggerServerEvent('esx_clans:setClanBase', {
                        x = coords.x,
                        y = coords.y,
                        z = coords.z
                    })
                end
            end
        })
        
        -- Opción para eliminar la marca de base
        if clanBase then
            table.insert(options, {
                title = 'Eliminar marca de BASE',
                description = 'Elimina la marca actual de base del clan',
                icon = 'map-marker-alt',
                onSelect = function()
                    local alert = lib.alertDialog({
                        header = 'Eliminar BASE',
                        content = '¿Quieres eliminar la marca actual de base del clan?\nPodrás establecer una nueva ubicación después.',
                        centered = true,
                        cancel = true
                    })
                    
                    if alert == 'confirm' then
                        TriggerServerEvent('esx_clans:removeClanBase')
                    end
                end
            })
        end
        
        table.insert(options, {
            title = Config.Locale['delete_clan'],
            description = 'Elimina permanentemente tu clan',
            icon = 'trash-alt',
            onSelect = function()
                local alert = lib.alertDialog({
                    header = Config.Locale['delete_clan'],
                    content = '¿Estás seguro de que quieres eliminar tu clan? Esta acción no se puede deshacer.',
                    centered = true,
                    cancel = true
                })
                
                if alert == 'confirm' then
                    TriggerServerEvent('esx_clans:deleteClan')
                end
            end
        })
    end
    
    table.insert(options, {
        title = Config.Locale['list_members'],
        description = 'Ver todos los miembros del clan',
        icon = 'users',
        onSelect = function()
            local memberOptions = {}
            
            for _, member in ipairs(clanMembers) do
                local title = member.name
                if member.isLeader then
                    title = title .. ' ' .. Config.Locale['leader']
                end
                
                table.insert(memberOptions, {
                    title = title,
                })
            end
            
            lib.registerContext({
                id = 'members_menu',
                title = Config.Locale['members_list'],
                menu = 'clan_menu',
                options = memberOptions
            })
            
            lib.showContext('members_menu')
        end
    })
    
    table.insert(options, {
        title = Config.Locale['toggle_hud'],
        description = 'Activa o desactiva el HUD de miembros',
        icon = showHUD and 'toggle-on' or 'toggle-off',
        onSelect = function()
            ToggleHUD()
            OpenClanMenu()
        end
    })
    
    lib.registerContext({
        id = 'clan_menu',
        title = clanName,
        options = options
    })
    
    lib.showContext('clan_menu')
end

-- Recibir invitación al clan
RegisterNetEvent('esx_clans:receiveClanInvite')
AddEventHandler('esx_clans:receiveClanInvite', function(id, name, inviterId)
    local alert = lib.alertDialog({
        header = 'Invitación a Clan',
        content = string.format(Config.Locale['received_invite'], name),
        centered = true,
        cancel = true
    })
    
    if alert == 'confirm' then
        TriggerServerEvent('esx_clans:acceptInvite', id, inviterId)
    end
end)

-- Actualizar información del clan
RegisterNetEvent('esx_clans:updateClanInfo')
AddEventHandler('esx_clans:updateClanInfo', function(id, name, leader)
    clanId = id
    clanName = name
    isLeader = leader
    RefreshClanMembers()
    
    -- Inicializar el HUD NUI
    if showHUD then
        Citizen.Wait(500) -- Pequeña espera para asegurar que los datos se han cargado
        UpdateNUIHUD()
    end
end)

-- Actualizar lista de miembros
RegisterNetEvent('esx_clans:updateMembersList')
AddEventHandler('esx_clans:updateMembersList', function()
    RefreshClanMembers()
end)

-- Salir del clan
RegisterNetEvent('esx_clans:leftClan')
AddEventHandler('esx_clans:leftClan', function()
    clanId = nil
    clanName = nil
    isLeader = false
    clanMembers = {}
    RemoveAllClanBlips()
    RemoveClanBaseBlip() -- Eliminar blip de la base al salir del clan
    
    -- Ocultar el HUD NUI
    SendNUIMessage({
        action = 'toggleVisibility',
        show = false
    })
end)

-- Actualizar la base del clan
RegisterNetEvent('esx_clans:updateClanBase')
AddEventHandler('esx_clans:updateClanBase', function(coords)
    if coords and coords.x and coords.y and coords.z then
        CreateClanBaseBlip(coords)
        
        lib.notify({
            title = 'Clan',
            description = 'La base del clan ha sido actualizada',
            type = 'info'
        })
    end
end)

-- Eliminar la base del clan
RegisterNetEvent('esx_clans:removeClanBase')
AddEventHandler('esx_clans:removeClanBase', function()
    RemoveClanBaseBlip()
    
    lib.notify({
        title = 'Clan',
        description = 'La base del clan ha sido eliminada',
        type = 'info'
    })
end)

-- HUD NUI - Actualizar periódicamente para detectar cambios
Citizen.CreateThread(function()
    Citizen.Wait(2000) -- Esperar un poco al inicio para que todo esté cargado
    
    while true do
        if clanId then
            -- Refrescar miembros y actualizar el HUD NUI
            RefreshClanMembers()
        end
        Citizen.Wait(Config.HUD.updateInterval)
    end
end)

-- Inicializar HUD NUI cuando el jugador se carga completamente
AddEventHandler('esx:playerLoaded', function()
    -- Pequeña espera para que todos los datos se carguen correctamente
    Citizen.Wait(2000)
    
    ESX.TriggerServerCallback('esx_clans:getPlayerClan', function(clan)
        if clan then
            clanId = clan.id
            clanName = clan.name
            isLeader = clan.isLeader
            
            -- Crear blip de la base si existe
            if clan.base then
                CreateClanBaseBlip(clan.base)
            end
            
            RefreshClanMembers()
            
            -- Mostrar el HUD NUI si está habilitado
            if showHUD then
                UpdateNUIHUD()
            end
        end
    end)
end)

-- Actualizar blips en el mapa
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(Config.BlipUpdateTime)
        
        if clanId then
            UpdateClanMembersBlips()
        end
    end
end)
