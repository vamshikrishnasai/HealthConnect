import { LightningElement, api } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import isGuest from "@salesforce/user/isGuest";

export default class HealthConnectPortalLogout extends NavigationMixin(
  LightningElement
) {
  @api compact = false;

  get isAuthenticatedUser() {
    return !isGuest;
  }

  get logoutBarClass() {
    return this.compact ? "logout-bar logout-bar--compact" : "logout-bar";
  }

  handleLogout() {
    this[NavigationMixin.Navigate]({
      type: "comm__loginPage",
      attributes: {
        actionName: "logout"
      }
    });
  }
}
