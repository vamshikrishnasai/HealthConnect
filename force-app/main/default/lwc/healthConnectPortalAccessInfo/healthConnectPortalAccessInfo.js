import { LightningElement } from "lwc";
import communityBasePath from "@salesforce/community/basePath";

export default class HealthConnectPortalAccessInfo extends LightningElement {
  get loginUrl() {
    return `${communityBasePath}/login`;
  }
}
