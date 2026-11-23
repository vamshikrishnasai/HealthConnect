import { createElement } from "lwc";
import HealthConnectPortalLogout from "c/healthConnectPortalLogout";

jest.mock("@salesforce/user/isGuest", () => ({ default: false }), {
  virtual: true
});

const flushPromises = async () => {
  await Promise.resolve();
  await Promise.resolve();
  await Promise.resolve();
};

describe("c-health-connect-portal-logout", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("renders the styled compact logout button for the Doctor portal", async () => {
    const element = createElement("c-health-connect-portal-logout", {
      is: HealthConnectPortalLogout
    });
    element.compact = true;
    document.body.appendChild(element);
    await flushPromises();

    const logoutButton = element.shadowRoot.querySelector(
      "button.logout-button"
    );
    expect(logoutButton).not.toBeNull();
    expect(logoutButton.textContent).toContain("Log out");
  });

  it("keeps the default logout button for other portal uses", async () => {
    const element = createElement("c-health-connect-portal-logout", {
      is: HealthConnectPortalLogout
    });
    document.body.appendChild(element);
    await flushPromises();

    expect(element.shadowRoot.querySelector("lightning-button")).not.toBeNull();
  });
});
