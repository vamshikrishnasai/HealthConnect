import { createElement } from "lwc";
import getAssignedAppointments from "@salesforce/apex/HealthConnectDoctorPortalController.getAssignedAppointments";
import getAssignedCases from "@salesforce/apex/HealthConnectDoctorPortalController.getAssignedCases";
import saveCaseReviewAction from "@salesforce/apex/HealthConnectDoctorPortalController.saveCaseReview";
import getCurrentDoctorProfile from "@salesforce/apex/HealthConnectDoctorProfileController.getCurrentDoctorProfile";
import saveCurrentDoctorProfile from "@salesforce/apex/HealthConnectDoctorProfileController.saveCurrentDoctorProfile";
import HealthConnectDoctorDashboard from "c/healthConnectDoctorDashboard";

jest.mock(
  "@salesforce/apex/HealthConnectDoctorPortalController.getAssignedAppointments",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/HealthConnectDoctorPortalController.getAssignedCases",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/HealthConnectDoctorPortalController.saveCaseReview",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/HealthConnectDoctorProfileController.getCurrentDoctorProfile",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/HealthConnectDoctorProfileController.saveCurrentDoctorProfile",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

const flushPromises = async () => {
  await Promise.resolve();
  await Promise.resolve();
  await Promise.resolve();
};

describe("c-health-connect-doctor-dashboard", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("shows assigned cases and appointments and saves a case review", async () => {
    getAssignedCases.mockResolvedValue([
      {
        Id: "case-1",
        Name: "HC-0001",
        patientName: "Patient One",
        patientDateOfBirth: "1980-03-10",
        patientPhoneNumber: "555-0100",
        createdDate: "2026-10-20T10:00:00.000Z",
        lastModifiedDate: "2026-10-20T10:00:00.000Z",
        caseStatus: "Under Review",
        casePriority: "Medium",
        appointmentRequired: false,
        symptoms: "Persistent cough",
        diagnosis: "Respiratory infection",
        recommendation: "Rest",
        followUpDate: "2026-11-01"
      }
    ]);
    getAssignedAppointments.mockResolvedValue([
      {
        Id: "appointment-1",
        Name: "APT-0001",
        patientName: "Patient One",
        caseName: "HC-0001",
        appointmentDate: "2026-11-03",
        appointmentTime: "9:00 AM",
        appointmentStatus: "Scheduled",
        notes: "Bring recent test results"
      }
    ]);
    getCurrentDoctorProfile.mockResolvedValue({
      name: "Dr. Doctor",
      specialization: "General Physician",
      email: "doctor@example.test",
      phoneNumber: "555-0101",
      healthcareFacility: "HealthConnect Clinic",
      district: "Central",
      availabilityStatus: "Available"
    });
    saveCaseReviewAction.mockResolvedValue("2026-10-21T10:00:00.000Z");
    saveCurrentDoctorProfile.mockResolvedValue({
      name: "Dr. Doctor",
      specialization: "General Physician",
      email: "doctor@example.test",
      phoneNumber: "555-0199",
      healthcareFacility: "Updated Clinic",
      district: "South",
      availabilityStatus: "Unavailable"
    });

    const element = createElement("c-health-connect-doctor-dashboard", {
      is: HealthConnectDoctorDashboard
    });
    document.body.appendChild(element);
    await flushPromises();

    element.shadowRoot
      .querySelector(".profile-trigger")
      .dispatchEvent(new CustomEvent("click"));
    await flushPromises();

    expect(element.shadowRoot.textContent).toContain("Hello, Dr. Doctor");
    expect(element.shadowRoot.textContent).toContain("HealthConnect Clinic");
    expect(element.shadowRoot.textContent).toContain("General Physician");
    expect(element.shadowRoot.textContent).toContain("doctor@example.test");
    expect(element.shadowRoot.textContent).toContain("555-0101");
    expect(element.shadowRoot.textContent).toContain("DOCTOR WORKSPACE");
    expect(
      element.shadowRoot.querySelector('img[alt="Health Connect"]')
    ).not.toBeNull();
    expect(element.shadowRoot.textContent).toContain("Patient One");
    expect(element.shadowRoot.textContent).toContain("HC-0001");
    expect(element.shadowRoot.textContent).toContain("Persistent cough");
    expect(element.shadowRoot.textContent).toContain("APT-0001");
    expect(element.shadowRoot.textContent).toContain(
      "Bring recent test results"
    );

    element.shadowRoot
      .querySelector('button[title="Edit case review"]')
      .dispatchEvent(new CustomEvent("click"));
    await flushPromises();

    const diagnosisInput = element.shadowRoot.querySelector(
      'input[data-field="diagnosisDraft"]'
    );
    diagnosisInput.value = "Updated diagnosis";
    diagnosisInput.dispatchEvent(new CustomEvent("change"));
    await flushPromises();

    const recommendationInput = element.shadowRoot.querySelector(
      'textarea[data-field="recommendationDraft"]'
    );
    recommendationInput.value = "Hydrate and rest";
    recommendationInput.dispatchEvent(new CustomEvent("change"));

    const statusSelect = element.shadowRoot.querySelector(
      'select[data-field="caseStatusDraft"]'
    );
    statusSelect.value = "Follow-up Required";
    statusSelect.dispatchEvent(new CustomEvent("change"));
    await flushPromises();

    element.shadowRoot
      .querySelector(".save-actions .action-button--primary")
      .dispatchEvent(new CustomEvent("click"));
    await flushPromises();

    expect(saveCaseReviewAction).toHaveBeenCalledWith({
      healthCaseId: "case-1",
      diagnosis: "Updated diagnosis",
      recommendation: "Hydrate and rest",
      caseStatus: "Follow-up Required",
      appointmentRequired: false,
      followUpDate: "2026-11-01",
      expectedLastModifiedDate: "2026-10-20T10:00:00.000Z"
    });
    expect(element.shadowRoot.textContent).toContain("Case review saved.");
    expect(
      element.shadowRoot.querySelector('button[title="Edit case review"]')
    ).not.toBeNull();
    expect(element.shadowRoot.querySelector("lightning-button")).toBeNull();
  });

  it("shows an empty state when no cases or appointments are assigned", async () => {
    getAssignedCases.mockResolvedValue([]);
    getAssignedAppointments.mockResolvedValue([]);
    getCurrentDoctorProfile.mockResolvedValue({
      name: "Dr. Doctor"
    });

    const element = createElement("c-health-connect-doctor-dashboard", {
      is: HealthConnectDoctorDashboard
    });
    document.body.appendChild(element);
    await flushPromises();

    expect(element.shadowRoot.textContent).toContain(
      "No cases are assigned to you"
    );
  });

  it("opens, edits, and saves the approved Doctor profile fields", async () => {
    getAssignedCases.mockResolvedValue([]);
    getAssignedAppointments.mockResolvedValue([]);
    getCurrentDoctorProfile.mockResolvedValue({
      name: "Dr. Doctor",
      specialization: "General Physician",
      email: "doctor@example.test",
      phoneNumber: "555-0101",
      healthcareFacility: "HealthConnect Clinic",
      district: "Central",
      availabilityStatus: "Available"
    });
    saveCurrentDoctorProfile.mockResolvedValue({
      name: "Dr. Doctor",
      specialization: "Cardiologist",
      email: "doctor@example.test",
      phoneNumber: "555-0199",
      healthcareFacility: "Updated Clinic",
      district: "South",
      availabilityStatus: "Unavailable"
    });

    const element = createElement("c-health-connect-doctor-dashboard", {
      is: HealthConnectDoctorDashboard
    });
    document.body.appendChild(element);
    await flushPromises();

    expect(element.shadowRoot.querySelector(".profile-panel")).toBeNull();
    element.shadowRoot
      .querySelector(".profile-trigger")
      .dispatchEvent(new CustomEvent("click"));
    await flushPromises();

    expect(element.shadowRoot.textContent).toContain("HealthConnect Clinic");
    element.shadowRoot
      .querySelector(".profile-panel .action-button--primary")
      .dispatchEvent(new CustomEvent("click"));
    await flushPromises();

    const phoneInput = element.shadowRoot.querySelector(
      'input[data-field="phoneNumber"]'
    );
    phoneInput.value = "555-0199";
    phoneInput.dispatchEvent(new CustomEvent("change"));
    const specializationSelect = element.shadowRoot.querySelector(
      'select[data-field="specialization"]'
    );
    specializationSelect.value = "Cardiologist";
    specializationSelect.dispatchEvent(new CustomEvent("change"));
    const facilityInput = element.shadowRoot.querySelector(
      'input[data-field="healthcareFacility"]'
    );
    facilityInput.value = "Updated Clinic";
    facilityInput.dispatchEvent(new CustomEvent("change"));
    const districtInput = element.shadowRoot.querySelector(
      'input[data-field="district"]'
    );
    districtInput.value = "South";
    districtInput.dispatchEvent(new CustomEvent("change"));
    const availabilitySelect = element.shadowRoot.querySelector(
      'select[data-field="availabilityStatus"]'
    );
    availabilitySelect.value = "Unavailable";
    availabilitySelect.dispatchEvent(new CustomEvent("change"));
    await flushPromises();

    element.shadowRoot
      .querySelector(".profile-panel .action-button--primary")
      .dispatchEvent(new CustomEvent("click"));
    await flushPromises();

    expect(saveCurrentDoctorProfile).toHaveBeenCalledWith({
      phoneNumber: "555-0199",
      specialization: "Cardiologist",
      healthcareFacility: "Updated Clinic",
      district: "South",
      availabilityStatus: "Unavailable"
    });
    expect(element.shadowRoot.textContent).toContain(
      "Profile updated successfully."
    );
    expect(element.shadowRoot.textContent).toContain("Updated Clinic");
  });

  it("keeps case and appointment data visible when the Doctor profile link is missing", async () => {
    getAssignedCases.mockResolvedValue([
      {
        Id: "case-2",
        Name: "HC-0002",
        patientName: "Patient Two",
        caseStatus: "New",
        casePriority: "Low"
      }
    ]);
    getAssignedAppointments.mockResolvedValue([]);
    getCurrentDoctorProfile.mockResolvedValue({
      name: "Portal Doctor",
      profileError:
        "Your Doctor record is not linked to this portal account. Contact your HealthConnect administrator."
    });

    const element = createElement("c-health-connect-doctor-dashboard", {
      is: HealthConnectDoctorDashboard
    });
    document.body.appendChild(element);
    await flushPromises();

    element.shadowRoot
      .querySelector(".profile-trigger")
      .dispatchEvent(new CustomEvent("click"));
    await flushPromises();

    expect(element.shadowRoot.textContent).toContain("Hello, Portal Doctor");
    expect(element.shadowRoot.textContent).toContain("HC-0002");
    expect(element.shadowRoot.textContent).toContain(
      "Your Doctor record is not linked to this portal account."
    );
    expect(element.shadowRoot.textContent).not.toContain(
      "We couldn’t load your dashboard"
    );
  });
});
