import { LightningElement, api } from "lwc";
import { CloseActionScreenEvent } from "lightning/actions";
import provisionDoctorPortalAccount from "@salesforce/apex/HCDoctorProvisioningController.provisionDoctorPortalAccount";

const getErrorMessage = (error) =>
  error?.body?.message ||
  error?.message ||
  "Salesforce could not complete provisioning. Retry or contact your administrator.";

export default class HealthConnectDoctorProvisioning extends LightningElement {
  @api recordId;

  isProvisioning = false;
  message;
  messageClass = "";
  messageRole = "status";

  get buttonLabel() {
    return this.isProvisioning ? "Provisioning…" : "Provision / Retry";
  }

  async provisionAccount() {
    this.isProvisioning = true;
    this.message = undefined;
    try {
      const result = await provisionDoctorPortalAccount({
        doctorId: this.recordId
      });
      this.message = result.message;
      if (result.status === "Pending") {
        this.messageClass = "slds-p-around_medium slds-text-color_default";
        this.messageRole = "status";
      } else {
        this.messageClass = result.activationEmailInitiated
          ? "slds-p-around_medium slds-text-color_success"
          : "slds-p-around_medium slds-text-color_error";
        this.messageRole = result.activationEmailInitiated ? "status" : "alert";
      }
    } catch (error) {
      this.message = getErrorMessage(error);
      this.messageClass = "slds-p-around_medium slds-text-color_error";
      this.messageRole = "alert";
    } finally {
      this.isProvisioning = false;
    }
  }

  closeAction() {
    this.dispatchEvent(new CloseActionScreenEvent());
  }
}
