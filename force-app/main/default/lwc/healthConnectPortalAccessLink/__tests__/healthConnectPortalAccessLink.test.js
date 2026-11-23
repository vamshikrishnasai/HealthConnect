import { createElement } from "lwc";
import HealthConnectPortalAccessLink from "c/healthConnectPortalAccessLink";

describe("c-health-connect-portal-access-link", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("links new users to the active HealthConnect signup form", () => {
    const element = createElement("c-health-connect-portal-access-link", {
      is: HealthConnectPortalAccessLink
    });
    document.body.appendChild(element);

    expect(element.shadowRoot.textContent).toContain("NEW TO HEALTHCONNECT?");
    expect(
      element.shadowRoot.querySelector(".auth-link").getAttribute("href")
    ).toBe("/s/login/SelfRegister");
  });
});
