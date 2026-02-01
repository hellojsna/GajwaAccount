//
//  auth.js
//  GajwaAccount
//
//  Created by Js Na on 2026/01/07.
//  Copyright © 2026 Js Na. All rights reserved.
//

let currentStep = 1;
let previousStep = 0;
const totalSteps = 6;

const loginView = document.getElementById("loginView");
const passwordLoginView = document.getElementById("passwordLoginView");
const registerView = document.getElementById("registerView");
const registerTitle = document.getElementById("registerTitle");
const progressFill = document.getElementById("progressFill");
const progressText = document.getElementById("progressText");

const stepContent = [
    { title: "이름을 입력해 주세요." },
    { title: "학번을 입력해 주세요." },
    { title: "이메일을 입력해 주세요." },
    { title: "로그인에 사용할 ID를 입력해 주세요." },
    { title: "비밀번호를 입력해 주세요." },
    { title: "이 기기에 패스키를 저장합니다." }
];

const validators = {
    userName: (value) => {
        const trimmed = value.trim();
        if (!trimmed) return { valid: false, message: "이름을 입력해주세요." };
        return { valid: true, message: "" };
    },
    
    userStudentID: (value) => {
        const trimmed = value.trim();
        if (!trimmed) return { valid: false, message: "학번을 입력해주세요." };
        if (trimmed.length !== 5) return { valid: false, message: "학번은 5자리 숫자여야 합니다." };
        if (!/^\d+$/.test(trimmed)) return { valid: false, message: "숫자만 입력 가능합니다." };
        return { valid: true, message: "" };
    },
    
    userEmail: (value) => {
        const trimmed = value.trim();
        if (!trimmed) return { valid: false, message: "이메일을 입력해주세요." };
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(trimmed)) return { valid: false, message: "올바른 이메일 형식이 아닙니다." };
        return { valid: true, message: "" };
    },
    
    userLoginID: (value) => {
        const trimmed = value.trim();
        if (!trimmed) return { valid: false, message: "로그인 ID를 입력해주세요." };
        if (trimmed.length < 4) return { valid: false, message: "ID는 4자 이상이어야 합니다." };
        if (!/^[a-zA-Z0-9]+$/.test(trimmed)) return { valid: false, message: "영문과 숫자만 사용 가능합니다." };
        return { valid: true, message: "" };
    },
    
    userLoginPassword: (value) => {
        if (!value) return { valid: false, message: "비밀번호를 입력해주세요." };
        if (value.length < 8) return { valid: false, message: "비밀번호는 8자 이상이어야 합니다." };
        return { valid: true, message: "" };
    },
    
    passwordLoginID: (value) => {
        const trimmed = value.trim();
        if (!trimmed) return { valid: false, message: "로그인 ID를 입력해주세요." };
        return { valid: true, message: "" };
    },
    
    passwordLoginPassword: (value) => {
        if (!value) return { valid: false, message: "비밀번호를 입력해주세요." };
        return { valid: true, message: "" };
    }
};

const originalHints = {
    "userStudentID": "5자리 숫자를 입력하세요.",
    "userEmail": "암호 복구에 사용됩니다.",
    "userLoginID": "영문 또는 숫자만 사용할 수 있습니다.",
    "userLoginPassword": "8자 이상 입력하세요."
};

const stepInputMap = {
    1: ["userName"],
    2: ["userStudentID"],
    3: ["userEmail"],
    4: ["userLoginID"],
    5: ["userLoginPassword"],
    6: []
};

function switchView(view) {
    loginView.classList.remove("active");
    passwordLoginView.classList.remove("active");
    registerView.classList.remove("active");
    
    if (view === "register") {
        registerView.classList.add("active");
    } else if (view === "passwordLogin") {
        passwordLoginView.classList.add("active");
    } else {
        loginView.classList.add("active");
    }
}

function updateStep(newStep) {
    previousStep = currentStep;
    currentStep = newStep;
    
    const steps = document.querySelectorAll(".formStep");
    const direction = currentStep > previousStep ? "slideInRight" : "slideInLeft";
    
    steps.forEach(step => {
        step.classList.remove("active", "slideInRight", "slideInLeft");
    });
    
    const activeStep = document.querySelector(`[data-step="${currentStep}"]`);
    if (activeStep) {
        activeStep.classList.add("active", direction);
    }
    
    updateProgress();
    updateHeader();
    updateStepButton(currentStep);
}

function updateProgress() {
    const progress = (currentStep / totalSteps) * 100;
    progressFill.style.width = `${progress}%`;
    progressText.textContent = `${currentStep} / ${totalSteps}`;
}

function updateHeader() {
    const content = stepContent[currentStep - 1];
    registerTitle.textContent = content.title;
}

function resetRegisterForm() {
    currentStep = 1;
    previousStep = 0;
    
    const inputs = ["userName", "userStudentID", "userEmail", "userLoginID", "userLoginPassword"];
    inputs.forEach(id => {
        const input = document.getElementById(id);
        if (input) {
            input.value = "";
            input.classList.remove("valid", "error");
            const container = input.closest(".studentIdInput");
            if (container) {
                container.classList.remove("valid", "error");
            }
        }
    });
    
    document.querySelectorAll(".inputHint").forEach(hint => {
        hint.classList.remove("valid", "error");
    });
    
    updateStep(1);
}

function validateInput(input) {
    const validator = validators[input.id];
    if (!validator) return true;
    
    const result = validator(input.value);
    const parent = input.closest(".inputGroup");
    const hint = parent?.querySelector(".inputHint");
    const container = input.closest(".studentIdInput");
    
    if (!input.value) {
        if (container) {
            container.classList.remove("valid", "error");
        } else {
            input.classList.remove("valid", "error");
        }
        if (hint) {
            hint.textContent = originalHints[input.id] || "";
            hint.classList.remove("valid", "error");
        }
        return false;
    }
    
    if (container) {
        container.classList.remove("valid", "error");
        container.classList.add(result.valid ? "valid" : "error");
    } else {
        input.classList.remove("valid", "error");
        input.classList.add(result.valid ? "valid" : "error");
    }
    
    if (hint) {
        hint.classList.remove("valid", "error");
        if (result.message) {
            hint.textContent = result.message;
            hint.classList.add(result.valid ? "valid" : "error");
        } else {
            hint.textContent = originalHints[input.id] || "";
        }
    }
    
    return result.valid;
}

function validateStep(step) {
    const inputIds = stepInputMap[step];
    if (!inputIds) return true;
    
    return inputIds.every(id => {
        const input = document.getElementById(id);
        return input ? validateInput(input) : true;
    });
}

function updateStepButton(step) {
    const activeStep = document.querySelector(`[data-step="${step}"]`);
    if (!activeStep) return;
    
    const nextButton = activeStep.querySelector(".nextStep");
    const submitButton = activeStep.querySelector("[type=\"submit\"]");
    const button = nextButton || submitButton;
    
    if (button) {
        const isValid = validateStep(step);
        button.disabled = !isValid;
    }
}

function updatePasswordLoginButton() {
    const loginIDInput = document.getElementById("passwordLoginID");
    const passwordInput = document.getElementById("passwordLoginPassword");
    const submitButton = document.querySelector("#passwordLoginForm [type=\"submit\"]");
    
    if (submitButton && loginIDInput && passwordInput) {
        const idValid = validators.passwordLoginID(loginIDInput.value).valid;
        const pwValid = validators.passwordLoginPassword(passwordInput.value).valid;
        submitButton.disabled = !(idValid && pwValid);
    }
}


document.getElementById("showRegisterView").addEventListener("click", (e) => {
    e.preventDefault();
    switchView("register");
    resetRegisterForm();
});

document.getElementById("showLoginView").addEventListener("click", (e) => {
    e.preventDefault();
    switchView("login");
});

document.getElementById("showPasswordLogin").addEventListener("click", (e) => {
    e.preventDefault();
    switchView("passwordLogin");
});

document.getElementById("showPasskeyLogin").addEventListener("click", (e) => {
    e.preventDefault();
    switchView("login");
});

document.querySelectorAll(".nextStep").forEach(button => {
    button.addEventListener("click", async (e) => {
        e.preventDefault();
        const step = parseInt(button.closest(".formStep")?.dataset.step);
        if (step && validateStep(step)) {
            if (step === 5 && typeof window.prepareRegistration === "function") {
                button.disabled = true;
                const prepared = await window.prepareRegistration();
                button.disabled = false;
                if (!prepared) return;
            }
            updateStep(step + 1);
        }
    });
});

document.querySelectorAll(".prevStep").forEach(button => {
    button.addEventListener("click", (e) => {
        e.preventDefault();
        const step = parseInt(button.closest(".formStep")?.dataset.step);
        if (step && step > 1) {
            updateStep(step - 1);
        }
    });
});

document.querySelectorAll(".formStep input").forEach(input => {
    input.addEventListener("input", () => {
        validateInput(input);
        const step = parseInt(input.closest(".formStep")?.dataset.step);
        if (step) updateStepButton(step);
    });
    
    input.addEventListener("blur", () => {
        validateInput(input);
        const step = parseInt(input.closest(".formStep")?.dataset.step);
        if (step) updateStepButton(step);
    });
});

["passwordLoginID", "passwordLoginPassword"].forEach(id => {
    const input = document.getElementById(id);
    if (input) {
        input.addEventListener("input", () => {
            validateInput(input);
            updatePasswordLoginButton();
        });
        input.addEventListener("blur", () => {
            validateInput(input);
            updatePasswordLoginButton();
        });
    }
});

document.querySelectorAll(".formStep input").forEach(input => {
    input.addEventListener("keypress", (e) => {
        if (e.key === "Enter") {
            e.preventDefault();
            const step = input.closest(".formStep");
            const nextButton = step.querySelector(".nextStep");
            const submitButton = step.querySelector("[type=\"submit\"]");
            
            if (nextButton && !nextButton.disabled) {
                nextButton.click();
            } else if (submitButton && !submitButton.disabled) {
                submitButton.click();
            }
        }
    });
});

const observer = new MutationObserver((mutations) => {
    mutations.forEach((mutation) => {
        if (mutation.target.classList.contains("active")) {
            const input = mutation.target.querySelector("input");
            if (input) {
                setTimeout(() => input.focus(), 100);
            }
        }
    });
});

document.querySelectorAll(".formStep").forEach(step => {
    observer.observe(step, { attributes: true, attributeFilter: ["class"] });
});

const passwordLoginForm = document.getElementById("passwordLoginForm");
if (passwordLoginForm) {
    passwordLoginForm.addEventListener("submit", async function(event) {
        event.preventDefault();
        
        const userLoginID = document.getElementById("passwordLoginID").value.trim();
        const userLoginPassword = document.getElementById("passwordLoginPassword").value;
        
        if (!userLoginID || !userLoginPassword) {
            alert("로그인 ID와 비밀번호를 입력해주세요.");
            return;
        }
        
        try {
            const response = await fetch("/api/v1/auth/login/password", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    userLoginID: userLoginID,
                    userLoginPassword: userLoginPassword
                })
            });
            
            if (response.ok) {
                const result = await response.json();
                location.href = result.redirectURL || "/home";
            } else {
                alert("로그인 실패. ID 또는 비밀번호를 올바르게 입력했는지 확인해주세요.");
            }
        } catch (error) {
            console.error("Login error:", error);
            alert("로그인 오류가 발생했습니다.");
        }
    });
}

updateProgress();
updateHeader();
updateStepButton(1);
updatePasswordLoginButton();