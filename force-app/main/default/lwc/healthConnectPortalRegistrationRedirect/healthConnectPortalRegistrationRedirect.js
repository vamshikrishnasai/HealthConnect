import { LightningElement } from "lwc";

export default class HealthConnectPortalRegistrationRedirect extends LightningElement {
  connectedCallback() {
    window.location.assign("/s/login/SelfRegister");
  }
}
