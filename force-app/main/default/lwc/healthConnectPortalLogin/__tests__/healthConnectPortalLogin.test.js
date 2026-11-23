import { createElement } from "lwc";
import HealthConnectPortalLogin from "c/healthConnectPortalLogin";

jest.mock("@salesforce/community/basePath", () => "/s", { virtual: true });
jest.mock(
  "@salesforce/apex/HealthConnectPortalLoginController.login",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

describe("c-health-connect-portal-login", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("shows self-registration by default for the patient portal", () => {
    const element = createElement("c-health-connect-portal-login", {
      is: HealthConnectPortalLogin
    });
    document.body.appendChild(element);

    expect(
      element.shadowRoot.querySelector('a[href$="/SelfRegister"]')
    ).not.toBeNull();
  });

  it("supports a blue doctor login without self-registration", () => {
    const element = createElement("c-health-connect-portal-login", {
      is: HealthConnectPortalLogin
    });
    element.showSelfRegister = false;
    element.blueTheme = true;
    document.body.appendChild(element);

    expect(
      element.shadowRoot.querySelector(".login-card--blue")
    ).not.toBeNull();
    expect(
      element.shadowRoot.querySelector('a[href$="/SelfRegister"]')
    ).toBeNull();
    expect(element.shadowRoot.querySelector("h1").textContent).toBe(
      "Doctor portal sign in"
    );
    expect(
      element.shadowRoot.querySelector('svg[data-icon="username"]')
    ).not.toBeNull();
    expect(
      element.shadowRoot.querySelector('svg[data-icon="password"]')
    ).not.toBeNull();
  });
});
