//
//  auth.js
//  GajwaAccount
//
//  Created by Js Na on 2026/01/07.
//  Copyright © 2026 Js Na. All rights reserved.
//

document.getElementById("showRegisterView").addEventListener("click", function(e) {
    e.preventDefault();
    document.getElementById("loginView").classList.remove("active");
    document.getElementById("registerView").classList.add("active");
});
document.getElementById("showLoginView").addEventListener("click", function(e) {
    e.preventDefault();
    document.getElementById("registerView").classList.remove("active");
    document.getElementById("loginView").classList.add("active");
});