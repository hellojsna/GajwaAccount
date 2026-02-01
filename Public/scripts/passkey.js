//
//  passkey.js
//  GajwaAccount
//
//  Created by Js Na on 2026/01/31.
//  Copyright © 2026 Js Na. All rights reserved.
//

const listElement = document.getElementById("passkeyList");
const emptyElement = document.getElementById("passkeyEmpty");
const addButton = document.getElementById("addPasskey");

function formatPasskeyId(id) {
    if (!id) return "-";
    if (id.length <= 12) return id;
    return `${id.slice(0, 6)}...${id.slice(-4)}`;
}

function setLoading(loading) {
    if (addButton) {
        addButton.disabled = loading;
        addButton.textContent = loading ? "추가 중..." : "패스키 추가";
    }
}

function renderList(items) {
    if (!listElement || !emptyElement) return;
    listElement.innerHTML = "";

    if (!items.length) {
        emptyElement.classList.remove("hidden");
        return;
    }

    emptyElement.classList.add("hidden");

    items.forEach(item => {
        const li = document.createElement("li");
        li.className = "passkeyItem";

        const meta = document.createElement("div");
        meta.className = "passkeyMeta";

        const title = document.createElement("span");
        title.className = "passkeyId";
        title.textContent = `ID: ${formatPasskeyId(item.id)}`;

        const counter = document.createElement("span");
        counter.className = "body xsmall";
        counter.textContent = `SignCount: ${item.currentSignCount}`;

        meta.appendChild(title);
        meta.appendChild(counter);

        const actions = document.createElement("div");
        actions.className = "passkeyActions";

        const deleteButton = document.createElement("button");
        deleteButton.type = "button";
        deleteButton.className = "button secondaryButton";
        deleteButton.textContent = "삭제";
        deleteButton.addEventListener("click", () => deletePasskey(item.id));

        actions.appendChild(deleteButton);

        li.appendChild(meta);
        li.appendChild(actions);
        listElement.appendChild(li);
    });
}

async function loadPasskeys() {
    try {
        const response = await fetch("/api/v1/passkeys");
        if (!response.ok) {
            throw new Error("Failed to load passkeys");
        }
        const data = await response.json();
        renderList(Array.isArray(data) ? data : []);
    } catch (error) {
        console.error(error);
        alert("패스키 목록을 불러오지 못했습니다.");
    }
}

async function deletePasskey(id) {
    if (!id) return;
    if (!confirm("이 패스키를 삭제하시겠습니까?")) return;

    try {
        const response = await fetch(`/api/v1/passkeys/${encodeURIComponent(id)}`, {
            method: "DELETE"
        });
        if (!response.ok) {
            throw new Error("Failed to delete passkey");
        }
        await loadPasskeys();
    } catch (error) {
        console.error(error);
        alert("패스키 삭제에 실패했습니다.");
    }
}

async function addPasskey() {
    if (!window.PublicKeyCredential || !PublicKeyCredential.parseCreationOptionsFromJSON) {
        alert("이 브라우저에서는 패스키를 지원하지 않습니다.");
        return;
    }

    setLoading(true);
    try {
        const createResponse = await fetch("/api/v1/passkeys/create", { method: "POST" });
        if (!createResponse.ok) {
            throw new Error("Failed to start passkey creation");
        }

        const options = await createResponse.json();
        const publicKey = PublicKeyCredential.parseCreationOptionsFromJSON(options.publicKey);
        publicKey.authenticatorSelection = {
            ...(publicKey.authenticatorSelection ?? {}),
            residentKey: "preferred",
            userVerification: "preferred"
        };

        const credential = await navigator.credentials.create({ publicKey });
        const passkey = credential.toJSON();

        const saveResponse = await fetch("/api/v1/passkeys", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(passkey)
        });

        if (!saveResponse.ok) {
            throw new Error("Failed to save passkey");
        }

        await loadPasskeys();
        alert("패스키가 추가되었습니다.");
    } catch (error) {
        console.error(error);
        alert("패스키 추가에 실패했습니다.");
    } finally {
        setLoading(false);
    }
}

if (addButton) {
    addButton.addEventListener("click", addPasskey);
}

loadPasskeys();
