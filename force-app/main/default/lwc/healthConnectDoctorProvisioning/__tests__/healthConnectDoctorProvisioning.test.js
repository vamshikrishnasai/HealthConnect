import { createElement } from "lwc";
import provisionDoctorPortalAccount from "@salesforce/apex/HCDoctorProvisioningController.provisionDoctorPortalAccount";
import HealthConnectDoctorProvisioning from "c/healthConnectDoctorProvisioning";

jest.mock("lightning/actions", () => ({ CloseActionScreenEvent: jest.fn() }), {
  virtual: true
});

jest.mock(
  "@salesforce/apex/HCDoctorProvisioningController.provisionDoctorPortalAccount",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

const flushPromises = async () => {
  await Promise.resolve();
  await Promise.resolve();
  await Promise.resolve();
};

describe("c-health-connect-doctor-provisioning", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("opens without a permission-check spinner and reports queued provisioning", async () => {
    provisionDoctorPortalAccount.mockResolvedValue({
      status: "Pending",
      message: "Portal access and password setup are processing.",
      activationEmailInitiated: false
    });

    const element = createElement("c-health-connect-doctor-provisioning", {
      is: HealthConnectDoctorProvisioning
    });
    element.recordId = "doctor-1";
    document.body.appendChild(element);

    const buttons = element.shadowRoot.querySelectorAll("lightning-button");
    expect(buttons).toHaveLength(2);
    expect(element.shadowRoot.querySelector("lightning-spinner")).toBeNull();

    buttons[1].dispatchEvent(new CustomEvent("click"));
    await flushPromises();

    expect(provisionDoctorPortalAccount).toHaveBeenCalledWith({
      doctorId: "doctor-1"
    });
    expect(element.shadowRoot.textContent).toContain(
      "Portal access and password setup are processing."
    );
    const pendingMessage = element.shadowRoot.querySelector('[role="status"]');
    expect(pendingMessage.className).toContain("slds-text-color_default");
    expect(element.shadowRoot.querySelector("lightning-spinner")).toBeNull();
  });

  it("surfaces provisioning errors and stops the progress indicator", async () => {
    provisionDoctorPortalAccount.mockRejectedValue({
      body: { message: "A Salesforce user already uses this email." }
    });

    const element = createElement("c-health-connect-doctor-provisioning", {
      is: HealthConnectDoctorProvisioning
    });
    element.recordId = "doctor-1";
    document.body.appendChild(element);

    element.shadowRoot
      .querySelectorAll("lightning-button")[1]
      .dispatchEvent(new CustomEvent("click"));
    await flushPromises();

    expect(element.shadowRoot.textContent).toContain(
      "A Salesforce user already uses this email."
    );
    expect(element.shadowRoot.querySelector("lightning-spinner")).toBeNull();
  });
});
