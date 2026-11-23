body.comm-page-login-home {
    min-height: 100vh;
    overflow-x: hidden;
    background:
        radial-gradient(circle at 9% 15%, rgba(8, 127, 130, .12), transparent 30%),
        radial-gradient(circle at 90% 88%, rgba(35, 155, 124, .10), transparent 28%),
        linear-gradient(135deg, #f3f8f7 0%, #e8f3f1 100%);
}

body.comm-page-login-home #LoginNew {
    min-height: 100vh;
    display: flex;
    flex-direction: column;
}

body.comm-page-login-home #centerPanel {
    width: 100%;
    max-width: none;
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: clamp(1rem, 4vw, 3rem);
    box-sizing: border-box;
}

body.comm-page-login-home .siteforceSldsOneColLayout.siteforceContentArea {
    width: 100%;
    max-width: 1120px;
    margin: 0 auto;
}

body.comm-page-login-home .contentRegion > div[data-region-name=content] {
    width: 100%;
    display: grid !important;
    grid-template-columns: minmax(0, 1.05fr) minmax(320px, .8fr);
    align-items: center;
    gap: clamp(2rem, 7vw, 6rem);
    box-sizing: border-box;
}

body.comm-page-login-home .contentRegion > div[data-region-name=content] > .ui-widget {
    width: 100%;
    min-width: 0;
}

body.comm-page-login-home .salesforceIdentityLoginForm2 {
    padding: clamp(1.5rem, 4vw, 2.6rem);
    border: 1px solid #e3eceb;
    border-radius: 22px;
    background: #ffffff;
    box-shadow: 0 24px 64px rgba(22, 50, 58, .12);
    box-sizing: border-box;
}

body.comm-page-login-home .salesforceIdentityLoginForm2 .inputContainer {
    position: relative;
    display: flex;
    align-items: center;
    min-height: 54px;
    margin: 0 0 1rem;
    padding: 0 .95rem;
    border: 1px solid #d6e5e3;
    border-radius: 11px;
    background: #f8fbfa;
    box-sizing: border-box;
}

body.comm-page-login-home .salesforceIdentityLoginForm2 .inputContainer:focus-within {
    border-color: #087f82;
    box-shadow: 0 0 0 3px rgba(8, 127, 130, .12);
}

body.comm-page-login-home .salesforceIdentityLoginForm2 .inputIcon {
    flex: 0 0 auto;
    margin-right: .7rem;
    --slds-c-icon-color-foreground-default: #6b8386;
}

body.comm-page-login-home .salesforceIdentityLoginForm2 .inputBox {
    width: 100%;
    min-height: 50px;
    border: 0;
    outline: 0;
    background: transparent;
    color: #16323a;
    font-size: .95rem;
    box-shadow: none;
}

body.comm-page-login-home .salesforceIdentityLoginForm2 .loginButton {
    width: 100%;
    min-height: 52px;
    margin: .35rem 0 1rem;
    border: 0;
    border-radius: 11px;
    background: linear-gradient(105deg, #087f82, #06666a);
    box-shadow: 0 8px 18px rgba(8, 127, 130, .2);
    font-size: .96rem;
    font-weight: 700;
    transition: transform .15s ease, box-shadow .15s ease;
}

body.comm-page-login-home .salesforceIdentityLoginForm2 .loginButton:hover,
body.comm-page-login-home .salesforceIdentityLoginForm2 .loginButton:focus {
    background: #06666a;
    box-shadow: 0 10px 22px rgba(8, 127, 130, .26);
    transform: translateY(-1px);
}

body.comm-page-login-home .salesforceIdentityLoginForm2 a,
body.comm-page-login-home .employeeLoginLink a {
    color: #087f82 !important;
    font-weight: 600;
    text-decoration: none;
}

body.comm-page-login-home .salesforceIdentityLoginForm2 a:hover,
body.comm-page-login-home .employeeLoginLink a:hover {
    color: #06666a !important;
    text-decoration: underline;
}

body.comm-page-login-home .employeeLoginLink {
    margin-top: 1rem;
    text-align: center;
}

@media (max-width: 760px) {
    body.comm-page-login-home #centerPanel {
        align-items: flex-start;
        padding: 1rem;
    }

    body.comm-page-login-home .contentRegion > div[data-region-name=content] {
        max-width: 560px;
        grid-template-columns: minmax(0, 1fr);
        gap: 1rem;
        margin: 0 auto;
    }

    body.comm-page-login-home .salesforceIdentityLoginForm2 {
        padding: 1.15rem;
        border-radius: 17px;
    }
}
