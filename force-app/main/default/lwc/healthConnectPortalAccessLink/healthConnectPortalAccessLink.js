import { LightningElement } from "lwc";

export default class HealthConnectPortalAccessLink extends LightningElement {
  get registrationUrl() {
    return "/s/login/SelfRegister";
  }
}
