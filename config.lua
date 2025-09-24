Config = {}

-- Configuraciones generales
Config.InviteDistance = 5.0 -- Distancia máxima para invitar jugadores (metros)
Config.BlipUpdateTime = 3000 -- Tiempo entre actualizaciones de blips en el mapa (ms)

-- Configuración de la base del clan
Config.BaseBlip = {
    sprite = 492,        -- Sprite del blip (492 es un símbolo de casa)
    color = 5,           -- Color del blip (5 es amarillo)
    scale = 1.0,         -- Tamaño del blip
    label = 'Base del Clan' -- Texto que aparece al acercarse al blip
}

-- Configuración del HUD
Config.HUD = {
    enabled = true,         -- Activar/desactivar HUD por defecto (mantiene la opción de ocultar el HUD si se desea)
    updateInterval = 5000,  -- Intervalo de actualización del HUD (ms)
    maxDisplayMembers = 10  -- Máximo número de miembros a mostrar en el HUD
}

-- Traducción (puede expandirse para soporte multilenguaje)
Config.Locale = {
    -- Notificaciones
    ['clan_created'] = 'Clan creado exitosamente: %s',
    ['clan_deleted'] = 'Has eliminado tu clan',
    ['player_invited'] = 'Has invitado a %s a unirse a tu clan',
    ['received_invite'] = 'Has recibido una invitación para unirte al clan: %s',
    ['player_joined'] = '%s se ha unido a tu clan',
    ['you_joined'] = 'Te has unido al clan: %s',
    ['player_kicked'] = 'Has expulsado a %s de tu clan',
    ['you_kicked'] = 'Has sido expulsado del clan',
    ['already_in_clan'] = 'Ya perteneces a un clan',
    ['player_already_in_clan'] = 'Este jugador ya pertenece a un clan',
    ['clan_exists'] = 'Ya existe un clan con ese nombre',
    ['not_leader'] = 'No eres el líder de este clan',
    ['no_clan'] = 'No perteneces a ningún clan',
    ['no_players_nearby'] = 'No hay jugadores cerca',
    
    -- Menús
    ['clan_menu_title'] = 'Gestión de Clan',
    ['create_clan'] = 'Crear Clan',
    ['invite_player'] = 'Invitar Jugador',
    ['kick_member'] = 'Expulsar Miembro',
    ['delete_clan'] = 'Eliminar Clan',
    ['list_members'] = 'Listar Miembros',
    ['toggle_hud'] = 'Activar/Desactivar HUD',
    ['enter_clan_name'] = 'Introduce el nombre del clan',
    ['confirm_delete'] = 'Confirmar eliminación',
    ['confirm'] = 'Confirmar',
    ['cancel'] = 'Cancelar',
    ['members_list'] = 'Lista de Miembros',
    ['leader'] = '(Líder)',
}
