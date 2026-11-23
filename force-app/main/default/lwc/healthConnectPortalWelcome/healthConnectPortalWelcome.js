import { LightningElement, api } from "lwc";
import healthConnectLogo from "@salesforce/resourceUrl/HealthConnectLogo";

export default class HealthConnectPortalWelcome extends LightningElement {
  @api wideLayout = false;

  logoUrl = healthConnectLogo;

  get welcomeClass() {
    return this.wideLayout ? "welcome welcome--wide" : "welcome";
  }
}
