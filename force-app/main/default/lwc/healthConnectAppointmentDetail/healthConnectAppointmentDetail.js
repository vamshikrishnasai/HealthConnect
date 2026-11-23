import { api, LightningElement } from "lwc";

export default class HealthConnectAppointmentDetail extends LightningElement {
  @api appointment;

  handleClose() {
    this.dispatchEvent(new CustomEvent("close"));
  }
}
