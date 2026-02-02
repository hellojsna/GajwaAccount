//
//  home.js
//  GajwaAccount
//
//  Created by Js Na on 2026/01/31.
//  Copyright © 2026 Js Na. All rights reserved.
//

const modals = document.querySelectorAll(".modal");
const editButtons = document.querySelectorAll(".editButton");
const modalCloses = document.querySelectorAll(".modalClose");
const modalBackdrops = document.querySelectorAll(".modalBackdrop");
const modalCancelButtons = document.querySelectorAll(".buttonGroup .secondaryButton");

function openModal(modalId) {
    const modal = document.getElementById(modalId);
    if (modal) {
        modal.classList.add("active");
        document.body.style.overflow = "hidden";
    }
}

function closeModal(modal) {
    if (modal) {
        modal.classList.remove("active");
        document.body.style.overflow = "";
    }
}

editButtons.forEach(button => {
    button.addEventListener("click", () => {
        const modalId = button.getAttribute("data-modal");
        openModal(modalId);
    });
});

modalCloses.forEach(button => {
    button.addEventListener("click", () => {
        const modal = button.closest(".modal");
        closeModal(modal);
    });
});

modalBackdrops.forEach(backdrop => {
    backdrop.addEventListener("click", () => {
        const modal = backdrop.closest(".modal");
        closeModal(modal);
    });
});

modalCancelButtons.forEach(button => {
    button.addEventListener("click", () => {
        const modal = button.closest(".modal");
        closeModal(modal);
    });
});

// Close modal on ESC key
document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") {
        modals.forEach(modal => {
            if (modal.classList.contains("active")) {
                closeModal(modal);
            }
        });
    }
});

// Academic Year for Student ID
function initAcademicYearDropdown(academicYear) {
    const modalAcademicYearElement = document.getElementById("modalAcademicYear");
    if (!modalAcademicYearElement) return;
    
    const baseYear = parseInt(academicYear);
    // 기준 학년도 포함 이전 3년 (총 4년)
    for (let i = 0; i < 4; i++) {
        const year = baseYear - i;
        const option = document.createElement("option");
        option.value = year;
        option.textContent = `${year}학년도`;
        if (year === baseYear) {
            option.selected = true;
        }
        modalAcademicYearElement.appendChild(option);
    }
}

// Profile Edit Form
const profileEditForm = document.getElementById("profileEditForm");
if (profileEditForm) {
    profileEditForm.addEventListener("submit", async (e) => {
        e.preventDefault();
        const userName = document.getElementById("editUserName").value;
        const userEmail = document.getElementById("editUserEmail").value;

        try {
            const response = await fetch("/api/v1/user/profile", {
                method: "PATCH",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ userName, userEmail })
            });

            if (response.ok) {
                alert("프로필이 수정되었습니다.");
                location.reload();
            } else {
                throw new Error("Failed to update profile");
            }
        } catch (error) {
            console.error(error);
            alert("프로필 수정에 실패했습니다.");
        }
    });
}

// Student ID Add Form
const studentIdAddForm = document.getElementById("studentIdAddForm");
if (studentIdAddForm) {
    studentIdAddForm.addEventListener("submit", async (e) => {
        e.preventDefault();
        const academicYear = document.getElementById("modalAcademicYear").value;
        const studentID = document.getElementById("modalStudentID").value;

        if (!/^\d{5}$/.test(studentID)) {
            alert("5자리 숫자를 입력해주세요.");
            return;
        }

        const userStudentIDList = `${academicYear}-${studentID}`;

        try {
            const response = await fetch("/api/v1/user/student-id", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ userStudentIDList })
            });

            if (response.ok) {
                alert("학번이 추가되었습니다.");
                location.reload();
            } else {
                throw new Error("Failed to add student ID");
            }
        } catch (error) {
            console.error(error);
            alert("학번 추가에 실패했습니다.");
        }
    });
}

// Delete Student ID
window.deleteStudentId = async function(studentIdFull) {
    if (!confirm("이 학번을 삭제하시겠습니까?")) return;

    try {
        const response = await fetch(`/api/v1/user/student-id/${encodeURIComponent(studentIdFull)}`, {
            method: "DELETE"
        });

        if (response.ok) {
            alert("학번이 삭제되었습니다.");
            location.reload();
        } else {
            throw new Error("Failed to delete student ID");
        }
    } catch (error) {
        console.error(error);
        alert("학번 삭제에 실패했습니다.");
    }
};

// Password Change Form
const passwordChangeForm = document.getElementById("passwordChangeForm");
if (passwordChangeForm) {
    passwordChangeForm.addEventListener("submit", async (e) => {
        e.preventDefault();
        const currentPassword = document.getElementById("currentPassword").value;
        const newPassword = document.getElementById("newPassword").value;
        const confirmPassword = document.getElementById("confirmPassword").value;

        if (newPassword !== confirmPassword) {
            alert("새 비밀번호가 일치하지 않습니다.");
            return;
        }

        if (newPassword.length < 8) {
            alert("비밀번호는 8자 이상이어야 합니다.");
            return;
        }

        try {
            const response = await fetch("/api/v1/user/password", {
                method: "PATCH",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ currentPassword, newPassword })
            });

            if (response.ok) {
                alert("비밀번호가 변경되었습니다.");
                passwordChangeForm.reset();
                closeModal(document.getElementById("securityModal"));
            } else {
                throw new Error("Failed to change password");
            }
        } catch (error) {
            console.error(error);
            alert("비밀번호 변경에 실패했습니다.");
        }
    });
}

// Passkey Management (Integrated from passkey.js)
const passkeyListElement = document.getElementById("passkeyList");
const passkeyEmptyElement = document.getElementById("passkeyEmpty");
const addPasskeyButton = document.getElementById("addPasskey");

function formatPasskeyId(id) {
    if (!id) return "-";
    if (id.length <= 12) return id;
    return `${id.slice(0, 6)}...${id.slice(-4)}`;
}

function setPasskeyLoading(loading) {
    if (addPasskeyButton) {
        addPasskeyButton.disabled = loading;
        addPasskeyButton.textContent = loading ? "추가 중..." : "패스키 추가";
    }
}

function renderPasskeyList(items) {
    if (!passkeyListElement || !passkeyEmptyElement) return;
    passkeyListElement.innerHTML = "";

    if (!items.length) {
        passkeyEmptyElement.style.display = "block";
        return;
    }

    passkeyEmptyElement.style.display = "none";

    items.forEach(item => {
        const li = document.createElement("li");
        li.className = "passkeyItem";

        const meta = document.createElement("div");
        meta.className = "passkeyMeta";

        const title = document.createElement("span");
        title.textContent = `ID: ${formatPasskeyId(item.id)}`;

        const counter = document.createElement("span");
        counter.style.color = "var(--gray)";
        counter.textContent = `SignCount: ${item.currentSignCount}`;

        meta.appendChild(title);
        meta.appendChild(counter);

        const actions = document.createElement("div");
        actions.className = "passkeyActions";

        const deleteButton = document.createElement("button");
        deleteButton.type = "button";
        deleteButton.className = "secondaryButton";
        deleteButton.textContent = "사용 중단";
        deleteButton.addEventListener("click", () => deletePasskey(item.id));

        actions.appendChild(deleteButton);

        li.appendChild(meta);
        li.appendChild(actions);
        passkeyListElement.appendChild(li);
    });
}

async function loadPasskeys() {
    try {
        const response = await fetch("/api/v1/passkeys");
        if (!response.ok) {
            throw new Error("Failed to load passkeys");
        }
        const data = await response.json();
        renderPasskeyList(Array.isArray(data) ? data : []);
    } catch (error) {
        console.error(error);
        // Don't show alert on initial load failure
    }
}

async function deletePasskey(id) {
    if (!id) return;
    if (!confirm("이 패스키의 사용을 중단할까요?")) return;

    try {
        const response = await fetch(`/api/v1/passkeys/${encodeURIComponent(id)}`, {
            method: "DELETE"
        });
        if (!response.ok) {
            throw new Error("Failed to delete passkey");
        }
        await loadPasskeys();
        alert("패스키 사용을 중단했습니다. 저장된 기기에서 직접 삭제해야 할 수도 있습니다.");
    } catch (error) {
        console.error(error);
        alert("패스키 사용 중단에 실패했습니다.");
    }
}

async function addPasskey() {
    if (!window.PublicKeyCredential || !PublicKeyCredential.parseCreationOptionsFromJSON) {
        alert("이 브라우저에서는 패스키를 지원하지 않습니다.");
        return;
    }

    setPasskeyLoading(true);
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
        setPasskeyLoading(false);
    }
}

if (addPasskeyButton) {
    addPasskeyButton.addEventListener("click", addPasskey);
}

const securityModal = document.getElementById("securityModal");
if (securityModal) {
    const securityEditButton = document.querySelector('[data-modal="securityModal"]');
    if (securityEditButton) {
        securityEditButton.addEventListener("click", () => {
            loadPasskeys();
        });
    }
}

// Developer Verification
const devVerifyButton = document.getElementById("verifyDevButton");
const confirmDevVerifyButton = document.getElementById("confirmDevVerifyButton");

if (devVerifyButton) {
    devVerifyButton.addEventListener("click", () => {
        openModal("devVerifyModal");
    });
}

if (confirmDevVerifyButton) {
    confirmDevVerifyButton.addEventListener("click", () => {
        window.location.href = "/discord/authorize";
    });
}

// Account Deactivation
const deactivateAccountButton = document.getElementById("deactivateAccountButton");
if (deactivateAccountButton) {
    deactivateAccountButton.addEventListener("click", async () => {
        const confirmed = confirm(`정말 탈퇴하시겠습니까?\n\n7일 이내에 계정에 로그인하면 탈퇴가 취소됩니다.\n7일 이내에 로그인하지 않으면 데이터가 영구 삭제되며, 삭제된 데이터는 복구되지 않습니다.`);
        
        if (!confirmed) return;

        try {
            const response = await fetch("/api/v1/user/deactivate", {
                method: "POST"
            });
            
            if (response.ok) {
                alert("계정 탈퇴가 요청되었습니다.\n7일 이내에 로그인하지 않으면 데이터가 영구 삭제되며, 삭제된 데이터는 복구되지 않습니다.");
                window.location.href = "/auth";
            } else {
                throw new Error("Failed to deactivate account");
            }
        } catch (error) {
            console.error(error);
            alert("계정 탈퇴에 실패했습니다.");
        }
    });
}

// Discord OAuth 콜백 후 상태 확인
const urlParams = new URLSearchParams(window.location.search);
const devVerifyStatus = urlParams.get('dev_verify_status');
if (devVerifyStatus === 'success') {
    alert("Hello, Gajwa!\n개발자 인증이 완료되었습니다.");
    // URL 파라미터 제거 후 페이지 새로고침
    window.location.href = window.location.pathname;
} else if (devVerifyStatus === 'not_member') {
    alert("디스코드 서버에 가입되어 있지 않아 인증에 실패했습니다.");
    // URL 파라미터 제거
    window.history.replaceState({}, document.title, window.location.pathname);
}
