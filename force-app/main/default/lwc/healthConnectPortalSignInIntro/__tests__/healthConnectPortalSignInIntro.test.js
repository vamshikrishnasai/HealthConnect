import { createElement } from "lwc";
import HealthConnectPortalSignInIntro from "c/healthConnectPortalSignInIntro";

describe("c-health-connect-portal-sign-in-intro", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("renders an accessible heading for the sign-in form", () => {
    const element = createElement("c-health-connect-portal-sign-in-intro", {
      is: HealthConnectPortalSignInIntro
    });
    document.body.appendChild(element);

    expect(element.shadowRoot.querySelector("h1").textContent).toBe(
      "Welcome back"
    );
    expect(element.shadowRoot.textContent).toContain("SECURE PATIENT SIGN IN");
    const intro = element.shadowRoot.querySelector("section");
    expect(intro.getAttribute("aria-labelledby")).toBe(
      element.shadowRoot.querySelector("h1").id
    );
  });
});
