import { LightningElement, api } from "lwc";
import basePath from "@salesforce/community/basePath";
import login from "@salesforce/apex/HealthConnectPortalLoginController.login";

const DEFAULT_LOGIN_ERROR =
  "We couldn't sign you in. Check your username and password and try again.";

export default class HealthConnectPortalLogin extends LightningElement {
  @api forgotPasswordLabel = "Forgot password?";
  @api forgotPasswordUrl = "/ForgotPassword";
  @api loginButtonLabel = "Sign in";
  @api selfRegisterLabel = "Not a member? Sign up";
  @api selfRegisterUrl = "/SelfRegister";
  @api showSelfRegister;
  @api blueTheme = false;

  username = "";
  password = "";
  errorMessage = "";
  isLoading = false;

  get loginButtonText() {
    return this.isLoading ? "Signing in..." : this.loginButtonLabel;
  }

  get cardClass() {
    return this.blueTheme ? "login-card login-card--blue" : "login-card";
  }

  get forgotPasswordHref() {
    return this.routeHref(this.forgotPasswordUrl);
  }

  get shouldShowSelfRegister() {
    return this.showSelfRegister !== false;
  }

  get selfRegisterHref() {
    return this.routeHref(this.selfRegisterUrl);
  }

  handleUsernameInput(event) {
    this.username = event.target.value;
    this.errorMessage = "";
  }

  handlePasswordInput(event) {
    this.password = event.target.value;
    this.errorMessage = "";
  }

  async handleSubmit(event) {
    event.preventDefault();
    if (this.isLoading) {
      return;
    }

    this.errorMessage = "";
    const form = this.template.querySelector("form");
    if (!form.reportValidity()) {
      return;
    }

    this.isLoading = true;
    try {
      const redirectUrl = await login({
        username: this.username.trim(),
        password: this.password,
      });
      if (!redirectUrl) {
        this.errorMessage = DEFAULT_LOGIN_ERROR;
        return;
      }
      window.location.assign(redirectUrl);
    } catch (error) {
      console.error("HealthConnect portal sign-in failed.", error);
      this.errorMessage = DEFAULT_LOGIN_ERROR;
    } finally {
      this.isLoading = false;
    }
  }

  routeHref(route) {
    const normalizedBase = basePath.endsWith("/")
      ? basePath.slice(0, -1)
      : basePath;
    const normalizedRoute = route.startsWith("/") ? route : `/${route}`;
    return `${normalizedBase}${normalizedRoute}`;
  }
}
