local ESX = exports['es_extended']:getSharedObject()

-- Inicialización de tablas en la base de datos
MySQL.ready(function()
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `clans` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `name` varchar(50) NOT NULL,
            `leader` varchar(50) NOT NULL,
            `base_x` float NULL DEFAULT NULL,
            `base_y` float NULL DEFAULT NULL,
            `base_z` float NULL DEFAULT NULL,
            PRIMARY KEY (`id`),
            UNIQUE KEY `name` (`name`)
        )
    ]])
    
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `clan_members` (
            `clan_id` int(11) NOT NULL,
            `identifier` varchar(50) NOT NULL,
            PRIMARY KEY (`identifier`),
            KEY `clan_id` (`clan_id`)
        )
    ]])
end)

-- Cache local de clanes para mejorar rendimiento
local clanMembers = {}
local playerClans = {}
local clansData = {}

-- Función para cargar todos los clanes desde la DB
local function LoadClans()
    MySQL.Async.fetchAll('SELECT id, name, leader, base_x, base_y, base_z FROM clans', {}, function(clans)
        local newClanMembers = {}
        local newPlayerClans = {}
        local newClansData = {}

        for _, clan in ipairs(clans) do
            local clanId = clan.id

            newClansData[clanId] = {
                id = clan.id,
                name = clan.name,
                leader = clan.leader,
                base_x = clan.base_x,
                base_y = clan.base_y,
                base_z = clan.base_z
            }

            newClanMembers[clanId] = {}
        end

        MySQL.Async.fetchAll('SELECT clan_id, identifier FROM clan_members', {}, function(members)
            for _, row in ipairs(members) do
                local clanId = row.clan_id

                if not newClanMembers[clanId] then
                    newClanMembers[clanId] = {}
                end

                table.insert(newClanMembers[clanId], row.identifier)
                newPlayerClans[row.identifier] = clanId
            end

            for clanId, clanInfo in pairs(newClansData) do
                local membersList = newClanMembers[clanId] or {}
                local leaderFound = false

                for i = 1, #membersList do
                    if membersList[i] == clanInfo.leader then
                        leaderFound = true
                        break
                    end
                end

                if not leaderFound then
                    table.insert(membersList, clanInfo.leader)
                end

                newClanMembers[clanId] = membersList
                newPlayerClans[clanInfo.leader] = clanId
            end

            clanMembers = newClanMembers
            playerClans = newPlayerClans
            clansData = newClansData
        end)
    end)
end

-- Cargar clanes al inicio
LoadClans()

-- Obtener el clan del jugador
local function GetPlayerClan(identifier)
    local clanId = playerClans[identifier]

    if not clanId then
        return nil
    end

    return clansData[clanId]
end

-- Verificar si un jugador es líder de un clan
local function IsPlayerClanLeader(identifier)
    local clanId = playerClans[identifier]
    local clanInfo = clanId and clansData[clanId]

    if clanInfo and clanInfo.leader == identifier then
        return true
    end
    return false
end

-- Eventos del servidor
RegisterNetEvent('esx_clans:createClan')
AddEventHandler('esx_clans:createClan', function(clanName)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then return end
    
    local identifier = xPlayer.identifier
    
    -- Verificar si el jugador ya está en un clan
    if playerClans[identifier] then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Clan',
            description = Config.Locale['already_in_clan'],
            type = 'error'
        })
        return
    end
    
    -- Verificar si el nombre del clan ya existe
    MySQL.Async.fetchAll('SELECT id FROM clans WHERE name = @name', {
        ['@name'] = clanName
    }, function(result)
        if result and #result > 0 then
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Clan',
                description = Config.Locale['clan_exists'],
                type = 'error'
            })
        else
            -- Crear el clan
            MySQL.Async.insert('INSERT INTO clans (name, leader) VALUES (@name, @leader)', {
                ['@name'] = clanName,
                ['@leader'] = identifier
            }, function(clanId)
                -- Añadir al líder como miembro
                MySQL.Async.execute('INSERT INTO clan_members (clan_id, identifier) VALUES (@clanId, @identifier)', {
                    ['@clanId'] = clanId,
                    ['@identifier'] = identifier
                }, function()
                    -- Actualizar caché local
                    if not clanMembers[clanId] then clanMembers[clanId] = {} end
                    table.insert(clanMembers[clanId], identifier)
                    clansData[clanId] = {
                        id = clanId,
                        name = clanName,
                        leader = identifier,
                        base_x = nil,
                        base_y = nil,
                        base_z = nil
                    }
                    playerClans[identifier] = clanId

                    -- Notificar al cliente
                    TriggerClientEvent('ox_lib:notify', source, {
                        title = 'Clan',
                        description = string.format(Config.Locale['clan_created'], clanName),
                        type = 'success'
                    })
                    
                    -- Actualizar la lista de miembros del clan para el cliente
                    TriggerClientEvent('esx_clans:updateClanInfo', source, clanId, clanName, true)
                end)
            end)
        end
    end)
end)

RegisterNetEvent('esx_clans:invitePlayer')
AddEventHandler('esx_clans:invitePlayer', function(targetId)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    local xTarget = ESX.GetPlayerFromId(targetId)
    
    if not xPlayer or not xTarget then return end
    
    local identifier = xPlayer.identifier
    local targetIdentifier = xTarget.identifier
    
    -- Verificar si el jugador es líder del clan
    if not IsPlayerClanLeader(identifier) then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Clan',
            description = Config.Locale['not_leader'],
            type = 'error'
        })
        return
    end
    
    local clanId = playerClans[identifier]
    
    -- Verificar si el objetivo ya está en un clan
    if playerClans[targetIdentifier] then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Clan',
            description = Config.Locale['player_already_in_clan'],
            type = 'error'
        })
        return
    end
    
    local clanInfo = clansData[clanId]

    if not clanInfo then
        print(('^1[esx_clans] Clan %s no encontrado en cache al invitar jugadores^7'):format(tostring(clanId)))
        return
    end

    local clanName = clanInfo.name

    -- Notificar al jugador que invitó
    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Clan',
        description = string.format(Config.Locale['player_invited'], GetPlayerName(targetId)),
        type = 'success'
    })

    -- Enviar invitación al jugador objetivo
    TriggerClientEvent('esx_clans:receiveClanInvite', targetId, clanId, clanName, source)
end)

RegisterNetEvent('esx_clans:acceptInvite')
AddEventHandler('esx_clans:acceptInvite', function(clanId, inviterId)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then return end
    
    local identifier = xPlayer.identifier
    
    -- Verificar que el jugador no esté ya en un clan
    if playerClans[identifier] then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Clan',
            description = Config.Locale['already_in_clan'],
            type = 'error'
        })
        return
    end
    
    -- Verificar que el clan exista
    local clanInfo = clansData[clanId]

    if not clanInfo then
        print(('^1[esx_clans] Clan %s no encontrado en cache al aceptar invitación^7'):format(tostring(clanId)))
        return
    end

    local clanName = clanInfo.name

    -- Añadir al jugador al clan
    MySQL.Async.execute('INSERT INTO clan_members (clan_id, identifier) VALUES (@clanId, @identifier)', {
        ['@clanId'] = clanId,
        ['@identifier'] = identifier
    }, function()
        -- Actualizar caché local
        if not clanMembers[clanId] then clanMembers[clanId] = {} end
        table.insert(clanMembers[clanId], identifier)
        playerClans[identifier] = clanId

        -- Notificar al nuevo miembro
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Clan',
            description = string.format(Config.Locale['you_joined'], clanName),
            type = 'success'
        })

        -- Notificar al líder que invitó
        if inviterId then
            TriggerClientEvent('ox_lib:notify', inviterId, {
                title = 'Clan',
                description = string.format(Config.Locale['player_joined'], GetPlayerName(source)),
                type = 'success'
            })
        end

        -- Actualizar la lista de miembros del clan para el cliente
        TriggerClientEvent('esx_clans:updateClanInfo', source, clanId, clanName, false)

        -- Enviar actualización a todos los miembros del clan
        for _, memberId in pairs(ESX.GetPlayers()) do
            local xMember = ESX.GetPlayerFromId(memberId)
            if xMember and playerClans[xMember.identifier] == clanId then
                TriggerClientEvent('esx_clans:updateMembersList', memberId)
            end
        end
    end)
end)

RegisterNetEvent('esx_clans:kickMember')
AddEventHandler('esx_clans:kickMember', function(targetIdentifier)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then return end
    
    local identifier = xPlayer.identifier
    
    -- Verificar si el jugador es líder del clan
    if not IsPlayerClanLeader(identifier) then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Clan',
            description = Config.Locale['not_leader'],
            type = 'error'
        })
        return
    end
    
    local clanId = playerClans[identifier]
    
    -- Verificar si el objetivo está en el mismo clan
    if playerClans[targetIdentifier] ~= clanId then return end
    
    -- No permitir expulsar al líder
    if targetIdentifier == identifier then return end
    
    -- Eliminar miembro del clan
    MySQL.Async.execute('DELETE FROM clan_members WHERE clan_id = @clanId AND identifier = @identifier', {
        ['@clanId'] = clanId,
        ['@identifier'] = targetIdentifier
    }, function()
        -- Actualizar caché local
        for i, memberId in ipairs(clanMembers[clanId]) do
            if memberId == targetIdentifier then
                table.remove(clanMembers[clanId], i)
                break
            end
        end
        playerClans[targetIdentifier] = nil
        
        -- Notificar al líder
        local targetPlayer = ESX.GetPlayerFromIdentifier(targetIdentifier)
        local playerName = targetPlayer and targetPlayer.getName() or "Jugador offline"
            
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Clan',
            description = string.format(Config.Locale['player_kicked'], playerName),
            type = 'success'
        })
        
        -- Notificar al miembro expulsado si está conectado
        if targetPlayer then
            TriggerClientEvent('ox_lib:notify', targetPlayer.source, {
                title = 'Clan',
                description = Config.Locale['you_kicked'],
                type = 'error'
            })
            TriggerClientEvent('esx_clans:leftClan', targetPlayer.source)
        end
        
        -- Enviar actualización a todos los miembros del clan
        for _, memberId in pairs(ESX.GetPlayers()) do
            local xMember = ESX.GetPlayerFromId(memberId)
            if xMember and playerClans[xMember.identifier] == clanId then
                TriggerClientEvent('esx_clans:updateMembersList', memberId)
            end
        end
    end)
end)

RegisterNetEvent('esx_clans:deleteClan')
AddEventHandler('esx_clans:deleteClan', function()
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then return end
    
    local identifier = xPlayer.identifier
    
    -- Verificar si el jugador es líder del clan
    if not IsPlayerClanLeader(identifier) then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Clan',
            description = Config.Locale['not_leader'],
            type = 'error'
        })
        return
    end
    
    local clanId = playerClans[identifier]
    
    -- Eliminar clan y miembros
    MySQL.Async.execute('DELETE FROM clans WHERE id = @clanId', {
        ['@clanId'] = clanId
    }, function()
        MySQL.Async.execute('DELETE FROM clan_members WHERE clan_id = @clanId', {
            ['@clanId'] = clanId
        }, function()
            -- Notificar a todos los miembros
            for _, memberId in ipairs(clanMembers[clanId] or {}) do
                local memberPlayer = ESX.GetPlayerFromIdentifier(memberId)
                if memberPlayer then
                    TriggerClientEvent('esx_clans:leftClan', memberPlayer.source)
                    
                    if memberId ~= identifier then
                        TriggerClientEvent('ox_lib:notify', memberPlayer.source, {
                            title = 'Clan',
                            description = Config.Locale['clan_deleted'],
                            type = 'error'
                        })
                    end
                end
                playerClans[memberId] = nil
            end
            
            -- Limpiar caché local
            clanMembers[clanId] = nil
            clansData[clanId] = nil
            
            -- Notificar al líder
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Clan',
                description = Config.Locale['clan_deleted'],
                type = 'success'
            })
        end)
    end)
end)

-- Obtener miembros del clan
ESX.RegisterServerCallback('esx_clans:getClanMembers', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then 
        cb(nil)
        return
    end
    
    local identifier = xPlayer.identifier
    local clanId = playerClans[identifier]
    
    if not clanId then
        cb(nil)
        return
    end
    
    local members = {}
    local memberIds = clanMembers[clanId] or {}
    
    -- Usar pcall para capturar cualquier error y evitar que la función falle completamente
    pcall(function()
        for _, memberId in ipairs(memberIds) do
            if memberId then -- Verificar que el ID del miembro es válido
                local clanInfo = clansData[clanId]
                local isLeader = clanInfo and clanInfo.leader == memberId
                local memberName = nil
                local isOnline = false
                
                local success, memberPlayer = pcall(function() return ESX.GetPlayerFromIdentifier(memberId) end)
                
                if success and memberPlayer then
                    -- Jugador online - obtener nombre de forma segura
                    local nameSuccess, name = pcall(function() return memberPlayer.getName() end)
                    memberName = nameSuccess and name or "Jugador online"
                    isOnline = true
                else
                    -- Jugador offline - obtener nombre de la BD de forma segura
                    local dbSuccess, result = pcall(function()
                        return MySQL.Sync.fetchAll('SELECT firstname, lastname FROM users WHERE identifier = @identifier', {
                            ['@identifier'] = memberId
                        })
                    end)
                    
                    if dbSuccess and result and result[1] then
                        memberName = result[1].firstname .. ' ' .. result[1].lastname
                    else
                        memberName = "Jugador desconocido"
                    end
                    isOnline = false
                end
                
                table.insert(members, {
                    identifier = memberId,
                    name = memberName,
                    isLeader = isLeader,
                    online = isOnline
                })
            end
        end
    end)
    
    -- Siempre devolver algo válido al cliente
    cb(members)
end)

-- Obtener información del clan del jugador
ESX.RegisterServerCallback('esx_clans:getPlayerClan', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then 
        cb(nil)
        return
    end
    
    local identifier = xPlayer.identifier
    local clan = GetPlayerClan(identifier)
    
    if clan then
        local base = nil
        if clan.base_x and clan.base_y and clan.base_z then
            base = {
                x = clan.base_x,
                y = clan.base_y,
                z = clan.base_z
            }
        end
        
        cb({
            id = clan.id,
            name = clan.name,
            isLeader = clan.leader == identifier,
            base = base
        })
    else
        cb(nil)
    end
end)

-- Obtener jugadores cercanos
ESX.RegisterServerCallback('esx_clans:getNearbyPlayers', function(source, cb, maxDistance)
    local xPlayer = ESX.GetPlayerFromId(source)
    local nearbyPlayers = {}
    
    if not xPlayer then
        cb({})
        return
    end
    
    local playerCoords = xPlayer.getCoords(true)
    
    for _, playerId in pairs(ESX.GetPlayers()) do
        if source ~= playerId then
            local xTarget = ESX.GetPlayerFromId(playerId)
            
            -- Verificar que el jugador no esté en un clan
            if xTarget and not playerClans[xTarget.identifier] then
                local targetCoords = xTarget.getCoords(true)
                local distance = #(vector3(playerCoords.x, playerCoords.y, playerCoords.z) - vector3(targetCoords.x, targetCoords.y, targetCoords.z))
                
                if distance <= maxDistance then
                    table.insert(nearbyPlayers, {
                        id = playerId,
                        name = xTarget.getName()
                    })
                end
            end
        end
    end
    
    cb(nearbyPlayers)
end)

-- Obtener coordenadas de los miembros del clan
ESX.RegisterServerCallback('esx_clans:getClanMembersLocations', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then 
        cb({})
        return
    end
    
    local identifier = xPlayer.identifier
    local clanId = playerClans[identifier]
    
    if not clanId then
        cb({})
        return
    end
    
    local memberLocations = {}
    
    -- Proteger con pcall para evitar errores si algo falla
    pcall(function()
        for _, memberId in ipairs(clanMembers[clanId] or {}) do
            -- Verificar que el miembro existe
            if memberId then
                local memberPlayer = ESX.GetPlayerFromIdentifier(memberId)
                -- Verificar que el jugador está online y no es el que hace la petición
                if memberPlayer and memberPlayer.source ~= source then
                    local success, coords = pcall(function() return memberPlayer.getCoords(true) end)
                    local success2, name = pcall(function() return memberPlayer.getName() end)
                    
                    -- Solo añadir si ambas llamadas tuvieron éxito
                    if success and success2 and coords and name then
                        memberLocations[name] = {
                            x = coords.x,
                            y = coords.y,
                            z = coords.z
                        }
                    end
                end
            end
        end
    end)
    
    cb(memberLocations)
end)

-- Eventos para la base del clan
RegisterNetEvent('esx_clans:setClanBase')
AddEventHandler('esx_clans:setClanBase', function(coords)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then return end
    
    local identifier = xPlayer.identifier
    
    -- Verificar si el jugador es líder del clan
    if not IsPlayerClanLeader(identifier) then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Clan',
            description = Config.Locale['not_leader'],
            type = 'error'
        })
        return
    end
    
    local clanId = playerClans[identifier]
    
    -- Guardar las coordenadas de la base
    MySQL.Async.execute('UPDATE clans SET base_x = @x, base_y = @y, base_z = @z WHERE id = @clanId', {
        ['@x'] = coords.x,
        ['@y'] = coords.y,
        ['@z'] = coords.z,
        ['@clanId'] = clanId
    }, function()
        if clansData[clanId] then
            clansData[clanId].base_x = coords.x
            clansData[clanId].base_y = coords.y
            clansData[clanId].base_z = coords.z
        end
        -- Notificar al líder
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Clan',
            description = 'Base del clan marcada correctamente',
            type = 'success'
        })
        
        -- Notificar a todos los miembros del clan
        for _, memberId in pairs(ESX.GetPlayers()) do
            local xMember = ESX.GetPlayerFromId(memberId)
            if xMember and playerClans[xMember.identifier] == clanId then
                TriggerClientEvent('esx_clans:updateClanBase', memberId, {
                    x = coords.x,
                    y = coords.y,
                    z = coords.z
                })
            end
        end
    end)
end)

RegisterNetEvent('esx_clans:removeClanBase')
AddEventHandler('esx_clans:removeClanBase', function()
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then return end
    
    local identifier = xPlayer.identifier
    
    -- Verificar si el jugador es líder del clan
    if not IsPlayerClanLeader(identifier) then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Clan',
            description = Config.Locale['not_leader'],
            type = 'error'
        })
        return
    end
    
    local clanId = playerClans[identifier]
    
    -- Eliminar las coordenadas de la base
    MySQL.Async.execute('UPDATE clans SET base_x = NULL, base_y = NULL, base_z = NULL WHERE id = @clanId', {
        ['@clanId'] = clanId
    }, function()
        if clansData[clanId] then
            clansData[clanId].base_x = nil
            clansData[clanId].base_y = nil
            clansData[clanId].base_z = nil
        end
        -- Notificar al líder
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Clan',
            description = 'Marca de base del clan eliminada',
            type = 'info'
        })
        
        -- Notificar a todos los miembros del clan
        for _, memberId in pairs(ESX.GetPlayers()) do
            local xMember = ESX.GetPlayerFromId(memberId)
            if xMember and playerClans[xMember.identifier] == clanId then
                TriggerClientEvent('esx_clans:removeClanBase', memberId)
            end
        end
    end)
end)

-- Actualizar todos los clanes cuando un jugador se desconecta
AddEventHandler('esx:playerDropped', function(playerId, reason)
    -- Envolver todo en un pcall para evitar errores no capturados
    pcall(function()
        local xPlayer = ESX.GetPlayerFromId(playerId)
        
        if xPlayer and type(xPlayer) == "table" then
            local identifier = xPlayer.identifier
            if not identifier then return end
            
            local clanId = playerClans[identifier]
            
            if clanId then
                -- Actualizar lista de miembros para todos los miembros del clan
                -- para mostrar que este jugador está ahora offline
                local onlinePlayers = ESX.GetPlayers()
                for i=1, #onlinePlayers do
                    local memberId = onlinePlayers[i]
                    if memberId then
                        local xMember = ESX.GetPlayerFromId(memberId)
                        if xMember and type(xMember) == "table" and xMember.identifier and playerClans[xMember.identifier] == clanId then
                            TriggerClientEvent('esx_clans:updateMembersList', memberId)
                        end
                    end
                end
            end
        end
    end)
end)

-- Recargar clanes cuando un jugador se conecta
AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    -- Envolver todo en un pcall para evitar errores no capturados
    pcall(function()
        if not xPlayer or type(xPlayer) ~= "table" then return end
        
        local identifier = xPlayer.identifier
        if not identifier then return end
        
        -- Usar GetPlayerClan de forma segura
        local success, clan = pcall(function() return GetPlayerClan(identifier) end)
        
        if success and clan then
            -- Información mínima requerida
            local clanId = clan.id
            local clanName = clan.name or "Clan"
            local isLeader = clan.leader == identifier
            
            TriggerClientEvent('esx_clans:updateClanInfo', playerId, clanId, clanName, isLeader)
            
            -- Establecer base del clan si existe
            if clan.base_x and clan.base_y and clan.base_z then
                TriggerClientEvent('esx_clans:updateClanBase', playerId, {
                    x = clan.base_x,
                    y = clan.base_y,
                    z = clan.base_z
                })
            end
            
            -- Actualizar a todos los demás miembros del clan para mostrar que este jugador está online
            local onlinePlayers = ESX.GetPlayers()
            for i=1, #onlinePlayers do
                local memberId = onlinePlayers[i]
                if memberId and memberId ~= playerId then
                    local xMember = ESX.GetPlayerFromId(memberId)
                    if xMember and type(xMember) == "table" and xMember.identifier and playerClans[xMember.identifier] == clanId then
                        TriggerClientEvent('esx_clans:updateMembersList', memberId)
                    end
                end
            end
        end
    end)
end)
