//
//  oauth.js
//  GajwaAccount
//
//  Created by Js Na on 2026/02/01.
//  Copyright © 2026 Js Na. All rights reserved.
//

document.addEventListener('DOMContentLoaded', () => {
    const oauthModalTrigger = document.querySelector('[data-modal="oauthModal"]');
    if (oauthModalTrigger) {
        oauthModalTrigger.addEventListener('click', loadOAuthApps);
    }

    const createAppBtn = document.getElementById('createOAuthApp');
    if (createAppBtn) {
        createAppBtn.addEventListener('click', () => {
            openModal('createOAuthAppModal');
        });
    }

    const createForm = document.getElementById('createOAuthAppForm');
    if (createForm) {
        createForm.addEventListener('submit', handleCreateOAuthApp);
    }

    const editForm = document.getElementById('editOAuthAppForm');
    if (editForm) {
        editForm.addEventListener('submit', handleEditOAuthApp);
    }

    const addMoreUriBtn = document.getElementById('addMoreUri');
    if (addMoreUriBtn) {
        addMoreUriBtn.addEventListener('click', addRedirectUriField);
    }
});

async function loadOAuthApps() {
    try {
        const response = await fetch('/api/v1/oauth/apps', {
            method: 'GET',
            headers: {
                'Content-Type': 'application/json'
            }
        });

        if (!response.ok) {
            throw new Error(`Failed to load OAuth apps: ${response.statusText}`);
        }

        const apps = await response.json();
        displayOAuthApps(apps);
    } catch (error) {
        console.error('Error loading OAuth apps:', error);
        showNotification('OAuth 앱 목록을 불러올 수 없습니다.', 'error');
    }
}

function displayOAuthApps(apps) {
    const appsList = document.getElementById('oauthAppsList');
    const emptyState = document.getElementById('oauthEmptyState');
    const appCount = document.getElementById('oauthAppCount');

    appCount.textContent = apps.length;

    if (apps.length === 0) {
        appsList.innerHTML = '';
        appsList.appendChild(emptyState);
        return;
    }

    appsList.innerHTML = '';

    apps.forEach(app => {
        const appCard = document.createElement('div');
        appCard.className = 'oauthAppCard';

        appCard.innerHTML = `
            <div class="oauthAppRow">
                <div class="oauthAppInfo">
                    <h4 class="heading small oauthAppTitle">${escapeHtml(app.appName)}</h4>
                    <p class="oauthAppDesc">${escapeHtml(app.appDescription)}</p>
                    <div class="oauthAppMeta">
                        <p class="oauthAppClientRow">
                            <strong>Client ID:</strong> <code class="oauthAppClientCode">${escapeHtml(app.clientID)}</code>
                        </p>
                    </div>
                </div>
                <div class="oauthAppActions">
                    <button class="secondaryButton oauthAppActionButton" onclick="showOAuthAppDetails('${app.id}')">상세정보</button>
                    <button class="secondaryButton oauthAppActionButton" onclick="editOAuthApp('${app.id}')">수정</button>
                    <button class="secondaryButton oauthAppActionButton isDanger" onclick="deleteOAuthApp('${app.id}')">삭제</button>
                </div>
            </div>
        `;

        appsList.appendChild(appCard);
    });
}

async function handleCreateOAuthApp(event) {
    event.preventDefault();

    const appName = document.getElementById('oauthAppName').value;
    const appDescription = document.getElementById('oauthAppDescription').value;
    const redirectUri = document.getElementById('oauthRedirectUri').value;
    const homepageUrl = document.getElementById('oauthHomepageUrl').value;
    const logoUrl = document.getElementById('oauthLogoUrl').value;

    // Collect all redirect URIs
    const redirectURIs = [redirectUri];
    const additionalUris = document.querySelectorAll('input[name="additionalRedirectUri"]');
    additionalUris.forEach(input => {
        if (input.value.trim()) {
            redirectURIs.push(input.value.trim());
        }
    });

    const payload = {
        appName,
        appDescription,
        redirectURIs,
        homepageURL: homepageUrl || null,
        logoURL: logoUrl || null,
        scopes: ['profile', 'email']
    };

    try {
        const response = await fetch('/api/v1/oauth/apps', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(payload)
        });

        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.reason || 'Failed to create OAuth app');
        }

        const newApp = await response.json();
        
        // Close modal and refresh apps list
        closeModal('createOAuthAppModal');
        document.getElementById('createOAuthAppForm').reset();
        document.getElementById('additionalUris').innerHTML = '';
        
        showNotification('OAuth 앱이 생성되었습니다!', 'success');
        
        // Reload apps
        loadOAuthApps();
    } catch (error) {
        console.error('Error creating OAuth app:', error);
        showNotification(`OAuth 앱 생성 실패: ${error.message}`, 'error');
    }
}

function addRedirectUriField() {
    const container = document.getElementById('additionalUris');
    const fieldCount = container.children.length + 1;
    
    const wrapper = document.createElement('div');
    wrapper.className = 'inputGroup addUriGroup';
    
    wrapper.innerHTML = `
        <div class="oauthUriRow">
            <input type="url" name="additionalRedirectUri" class="oauthUriInput" placeholder="https://example.com/callback${fieldCount}">
            <button type="button" class="secondaryButton oauthUriRemoveButton" onclick="this.parentElement.parentElement.remove()">제거</button>
        </div>
    `;
    
    container.appendChild(wrapper);
}

async function showOAuthAppDetails(appId) {
    try {
        const response = await fetch(`/api/v1/oauth/apps/${appId}`, {
            method: 'GET',
            headers: {
                'Content-Type': 'application/json'
            }
        });

        if (!response.ok) {
            throw new Error(`Failed to load app details: ${response.statusText}`);
        }

        const app = await response.json();
        displayAppDetails(app);
        openModal('oauthAppDetailsModal');
    } catch (error) {
        console.error('Error loading app details:', error);
        showNotification('앱 상세 정보를 불러올 수 없습니다.', 'error');
    }
}

function displayAppDetails(app) {
    const detailsContent = document.getElementById('appDetailsContent');
    
    const baseURL = window.location.origin;
    const authorizationEndpoint = `${baseURL}/oauth/authorize`;
    const tokenEndpoint = `${baseURL}/oauth/token`;
    const userInfoEndpoint = `${baseURL}/oauth/userinfo`;
    
    const redirectUrisHtml = app.redirectURIs.map(uri => 
        `<div class="appDetailsRedirectItem">${escapeHtml(uri)}</div>`
    ).join('');

    // FIXME: 너무 HTML을 생으로 넣는 거 같은데?
    detailsContent.innerHTML = `
        <div class="appDetailsSection">
            <h4 class="heading xsmall appDetailsLabel">앱 이름</h4>
            <p class="appDetailsText">${escapeHtml(app.appName)}</p>
        </div>

        <div class="appDetailsSection">
            <h4 class="heading xsmall appDetailsLabel">설명</h4>
            <p class="appDetailsText">${escapeHtml(app.appDescription)}</p>
        </div>

        <div class="appDetailsSection">
            <h4 class="heading xsmall appDetailsLabel">Client ID</h4>
            <div class="appDetailsValueRow">
                <code class="appDetailsCode">${escapeHtml(app.clientID)}</code>
                <button type="button" class="secondaryButton appDetailsButton" onclick="copyToClipboard('${escapeHtml(app.clientID)}')">복사</button>
            </div>
        </div>

        <div class="appDetailsSection">
            <h4 class="heading xsmall appDetailsLabel">Client Secret</h4>
            <div class="appDetailsValueRow">
                <code id="clientSecretDisplay" class="appDetailsCode">••••••••••••••••••••••••••••••••</code>
                <button type="button" id="toggleSecretBtn" class="secondaryButton appDetailsButton" onclick="toggleClientSecret('${app.id}')">보기</button>
                <button type="button" class="secondaryButton appDetailsButton" onclick="copyClientSecret('${app.id}')">복사</button>
            </div>
            <p class="appDetailsWarning">보안을 위해 필요한 경우에만 확인하세요.</p>
        </div>

        <div class="appDetailsSection">
            <h4 class="heading xsmall appDetailsLabel">OAuth2 Endpoints</h4>
            <div style="display: flex; flex-direction: column; gap: 0.8rem;">
                <div>
                    <p class="body xsmall" style="color: var(--gray); margin-bottom: 0.4rem;">Authorization Endpoint</p>
                    <div class="appDetailsValueRow">
                        <code class="appDetailsCode">${escapeHtml(authorizationEndpoint)}</code>
                        <button type="button" class="secondaryButton appDetailsButton" onclick="copyToClipboard('${escapeHtml(authorizationEndpoint)}')">복사</button>
                    </div>
                </div>
                <div>
                    <p class="body xsmall" style="color: var(--gray); margin-bottom: 0.4rem;">Token Endpoint</p>
                    <div class="appDetailsValueRow">
                        <code class="appDetailsCode">${escapeHtml(tokenEndpoint)}</code>
                        <button type="button" class="secondaryButton appDetailsButton" onclick="copyToClipboard('${escapeHtml(tokenEndpoint)}')">복사</button>
                    </div>
                </div>
                <div>
                    <p class="body xsmall" style="color: var(--gray); margin-bottom: 0.4rem;">UserInfo Endpoint</p>
                    <div class="appDetailsValueRow">
                        <code class="appDetailsCode">${escapeHtml(userInfoEndpoint)}</code>
                        <button type="button" class="secondaryButton appDetailsButton" onclick="copyToClipboard('${escapeHtml(userInfoEndpoint)}')">복사</button>
                    </div>
                </div>
            </div>
        </div>

        <div class="appDetailsSection">
            <h4 class="heading xsmall appDetailsLabel">리다이렉트 URI</h4>
            <div>${redirectUrisHtml}</div>
        </div>

        <div class="appDetailsSection">
            <h4 class="heading xsmall appDetailsLabel">권한</h4>
            <div class="appDetailsScopes">
                ${app.scopes.map(scope => 
                    `<span class="appDetailsScopeBadge">${escapeHtml(scope)}</span>`
                ).join('')}
            </div>
        </div>

        <div class="appDetailsActions">
            <button type="button" class="secondaryButton appDetailsActionButton" onclick="regenerateClientSecret('${app.id}')">Secret 재생성</button>
        </div>
    `;

    document.getElementById('clientSecretDisplay').dataset.appId = app.id;
    document.getElementById('clientSecretDisplay').dataset.secret = app.clientSecret;
}

async function toggleClientSecret(appId) {
    const display = document.getElementById('clientSecretDisplay');
    const btn = document.getElementById('toggleSecretBtn');
    
    if (display.textContent.includes('•')) {
        display.textContent = display.dataset.secret;
        btn.textContent = '숨기기';
    } else {
        display.textContent = '••••••••••••••••••••••••••••••••';
        btn.textContent = '보기';
    }
}

async function copyClientSecret(appId) {
    const display = document.getElementById('clientSecretDisplay');
    const secret = display.dataset.secret;
    
    try {
        await navigator.clipboard.writeText(secret);
        showNotification('Client Secret이 복사되었습니다.', 'success');
    } catch (error) {
        console.error('Error copying:', error);
        showNotification('복사에 실패했습니다.', 'error');
    }
}

async function regenerateClientSecret(appId) {
    if (!confirm('정말로 Client Secret을 재생성하시겠습니까? 기존 Secret은 사용할 수 없게 됩니다.')) {
        return;
    }

    try {
        const response = await fetch(`/api/v1/oauth/apps/${appId}/regenerate-secret`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            }
        });

        if (!response.ok) {
            throw new Error(`Failed to regenerate secret: ${response.statusText}`);
        }

        const updatedApp = await response.json();
        displayAppDetails(updatedApp);
        showNotification('Secret이 재생성되었습니다.', 'success');
    } catch (error) {
        console.error('Error regenerating secret:', error);
        showNotification('Secret 재생성에 실패했습니다.', 'error');
    }
}

async function editOAuthApp(appId) {
    try {
        const response = await fetch(`/api/v1/oauth/apps/${appId}`, {
            method: 'GET',
            headers: {
                'Content-Type': 'application/json'
            }
        });

        if (!response.ok) {
            throw new Error(`Failed to load app details: ${response.statusText}`);
        }

        const app = await response.json();
        populateEditForm(app);
        closeModal('oauthAppDetailsModal');
        openModal('editOAuthAppModal');
    } catch (error) {
        console.error('Error loading app for edit:', error);
        showNotification('앱 정보를 불러올 수 없습니다.', 'error');
    }
}

function populateEditForm(app) {
    document.getElementById('editOAuthAppId').value = app.id;
    document.getElementById('editOAuthAppName').value = app.appName;
    document.getElementById('editOAuthAppDescription').value = app.appDescription;
    document.getElementById('editOAuthHomepageUrl').value = app.homepageURL || '';
    document.getElementById('editOAuthLogoUrl').value = app.logoURL || '';
    
    // Populate redirect URIs
    const container = document.getElementById('editRedirectUrisContainer');
    container.innerHTML = '';
    
    app.redirectURIs.forEach((uri, index) => {
        const wrapper = document.createElement('div');
        wrapper.className = index > 0 ? 'inputGroup addUriGroup' : 'inputGroup';
        
        wrapper.innerHTML = `
            <div class="oauthUriRow">
                <input type="url" class="editRedirectUri oauthUriInput" value="${escapeHtml(uri)}" ${index === 0 ? 'required' : ''}>
                ${index > 0 ? `<button type="button" class="secondaryButton oauthUriRemoveButton" onclick="this.parentElement.parentElement.remove()">제거</button>` : ''}
            </div>
        `;
        
        container.appendChild(wrapper);
    });
    
    // Set up add more URI button
    const addMoreBtn = document.getElementById('editAddMoreUri');
    addMoreBtn.onclick = () => addEditRedirectUriField();
}

function addEditRedirectUriField() {
    const container = document.getElementById('editRedirectUrisContainer');
    const fieldCount = container.children.length;
    
    const wrapper = document.createElement('div');
    wrapper.className = 'inputGroup addUriGroup';
    
    wrapper.innerHTML = `
        <div class="oauthUriRow">
            <input type="url" class="editRedirectUri oauthUriInput" placeholder="https://example.com/callback${fieldCount}">
            <button type="button" class="secondaryButton oauthUriRemoveButton" onclick="this.parentElement.parentElement.remove()">제거</button>
        </div>
    `;
    
    container.appendChild(wrapper);
}

async function handleEditOAuthApp(event) {
    event.preventDefault();

    const appId = document.getElementById('editOAuthAppId').value;
    const appName = document.getElementById('editOAuthAppName').value;
    const appDescription = document.getElementById('editOAuthAppDescription').value;
    const homepageUrl = document.getElementById('editOAuthHomepageUrl').value;
    const logoUrl = document.getElementById('editOAuthLogoUrl').value;

    // Collect all redirect URIs
    const redirectURIs = [];
    const uriInputs = document.querySelectorAll('.editRedirectUri');
    uriInputs.forEach(input => {
        if (input.value.trim()) {
            redirectURIs.push(input.value.trim());
        }
    });

    if (redirectURIs.length === 0) {
        showNotification('최소 하나의 리다이렉트 URI가 필요합니다.', 'error');
        return;
    }

    const payload = {
        appName,
        appDescription,
        redirectURIs,
        homepageURL: homepageUrl || null,
        logoURL: logoUrl || null
    };

    try {
        const response = await fetch(`/api/v1/oauth/apps/${appId}`, {
            method: 'PATCH',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(payload)
        });

        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.reason || 'Failed to update OAuth app');
        }

        closeModal('editOAuthAppModal');
        document.getElementById('editOAuthAppForm').reset();
        
        showNotification('OAuth 앱이 수정되었습니다!', 'success');
        
        // Reload apps
        loadOAuthApps();
    } catch (error) {
        console.error('Error updating OAuth app:', error);
        showNotification(`OAuth 앱 수정 실패: ${error.message}`, 'error');
    }
}

async function deleteOAuthApp(appId) {
    if (!confirm('정말로 이 앱을 삭제하시겠습니까?')) {
        return;
    }

    try {
        const response = await fetch(`/api/v1/oauth/apps/${appId}`, {
            method: 'DELETE',
            headers: {
                'Content-Type': 'application/json'
            }
        });

        if (!response.ok) {
            throw new Error(`Failed to delete app: ${response.statusText}`);
        }

        showNotification('앱이 삭제되었습니다.', 'success');
        loadOAuthApps();
        closeModal('oauthAppDetailsModal');
    } catch (error) {
        console.error('Error deleting app:', error);
        showNotification('앱 삭제에 실패했습니다.', 'error');
    }
}

function copyToClipboard(text) {
    navigator.clipboard.writeText(text).then(() => {
        showNotification('복사되었습니다.', 'success');
    }).catch(err => {
        console.error('Failed to copy:', err);
        showNotification('복사에 실패했습니다.', 'error');
    });
}

function escapeHtml(unsafe) {
    return unsafe
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#039;");
}

function openModal(modalId) {
    const modal = document.getElementById(modalId);
    if (modal) {
        modal.style.display = 'flex';
        // Prevent body scroll
        document.body.style.overflow = 'hidden';
    }
}

function closeModal(modalId) {
    const modal = document.getElementById(modalId);
    if (modal) {
        modal.style.display = 'none';
    }
    // Only restore scroll if no other modals are open
    const openModals = document.querySelectorAll('.modal[style*="display: flex"]');
    if (openModals.length === 0) {
        document.body.style.overflow = '';
    }
}

function showNotification(message, type = 'info') {
    // Simple notification (you can replace with a more elaborate toast system)
    alert(message);
}

// Modal close button handlers
document.addEventListener('DOMContentLoaded', () => {
    document.querySelectorAll('.modal').forEach(modal => {
        const backdrop = modal.querySelector('.modalBackdrop');
        const closeBtn = modal.querySelector('.modalClose');

        if (backdrop) {
            backdrop.addEventListener('click', () => {
                modal.style.display = 'none';
                document.body.style.overflow = '';
            });
        }

        if (closeBtn) {
            closeBtn.addEventListener('click', (e) => {
                e.preventDefault();
                modal.style.display = 'none';
                document.body.style.overflow = '';
            });
        }
    });
});


