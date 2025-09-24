/* 
 * ESX CLAN HUD JavaScript
 * Maneja la visualización y eventos del HUD de clanes 
 */

let clanVisible = false;
let clanCollapsed = false;

// Escuchar mensajes desde el cliente de FiveM
window.addEventListener('message', function(event) {
    const data = event.data;
    
    switch (data.action) {
        case 'updateClan':
            updateClanInfo(data.clanName, data.members);
            break;
            
        case 'toggleVisibility':
            toggleVisibility(data.show);
            break;
    }
});

// Actualiza la información del clan en el HUD
function updateClanInfo(clanName, members) {
    if (!clanName || !members) return;
    
    // Actualizar el nombre del clan
    document.getElementById('clan-name').textContent = clanName;
    
    // Limpiar lista de miembros
    const membersList = document.getElementById('members-list');
    membersList.innerHTML = '';
    
    // Agregar miembros a la lista
    members.forEach(member => {
        const memberItem = document.createElement('li');
        memberItem.className = 'member-item';
        
        const memberText = document.createElement('span');
        memberText.className = 'member-name';
        if (!member.online) {
            memberText.classList.add('member-offline');
        }
        memberText.textContent = member.name;
        
        memberItem.appendChild(memberText);
        
        // Si es líder, añadir indicador
        if (member.isLeader) {
            const leaderBadge = document.createElement('span');
            leaderBadge.className = 'leader';
            leaderBadge.innerHTML = '<i class="fas fa-crown"></i>';
            memberItem.appendChild(leaderBadge);
        }
        
        membersList.appendChild(memberItem);
    });
}

// Mostrar u ocultar el HUD
function toggleVisibility(show) {
    const clanContainer = document.getElementById('clan-container');
    
    if (show && !clanVisible) {
        clanContainer.classList.add('visible');
        clanVisible = true;
    } else if (!show && clanVisible) {
        clanContainer.classList.remove('visible');
        clanVisible = false;
    }
}

// Permitir colapsar/expandir el HUD al hacer clic en el encabezado
document.addEventListener('DOMContentLoaded', function() {
    const clanHeader = document.getElementById('clan-header');
    const clanContainer = document.getElementById('clan-container');
    
    clanHeader.addEventListener('click', function() {
        clanContainer.classList.toggle('collapsed');
        clanCollapsed = !clanCollapsed;
    });
});
