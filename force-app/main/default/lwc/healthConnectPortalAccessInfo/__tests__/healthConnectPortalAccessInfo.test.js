import { createElement } from "lwc";
import HealthConnectPortalAccessInfo from "c/healthConnectPortalAccessInfo";

jest.mock("@salesforce/community/basePath", () => "/s", { virtual: true });

describe("c-health-connect-portal-access-info", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("explains how to request access and provides a sign-in link", () => {
    const element = createElement("c-health-connect-portal-access-info", {
      is: HealthConnectPortalAccessInfo
    });
    document.body.appendChild(element);

    expect(element.shadowRoot.textContent).toContain("Request portal access");
    expect(element.shadowRoot.textContent).toContain(
      "accounts are set up by the HealthConnect care team"
    );
    expect(
      element.shadowRoot.querySelector(".sign-in-link").getAttribute("href")
    ).toBe("/s/login");
  });
});
