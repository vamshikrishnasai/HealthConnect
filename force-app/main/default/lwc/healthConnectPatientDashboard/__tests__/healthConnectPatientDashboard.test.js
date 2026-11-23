import { createElement } from "lwc";
import getDashboard from "@salesforce/apex/HealthConnectPatientDashboardController.getDashboard";
import ensurePatientForCurrentUser from "@salesforce/apex/HealthConnectPatientDashboardController.ensurePatientForCurrentUser";
import updatePatientProfile from "@salesforce/apex/HealthConnectPatientDashboardController.updatePatientProfile";
import hasDoctorPortalAccess from "@salesforce/apex/HealthConnectDoctorPortalController.hasDoctorPortalAccess";
import HealthConnectPatientDashboard from "c/healthConnectPatientDashboard";

jest.mock("@salesforce/user/isGuest", () => ({ default: false }), {
  virtual: true
});
jest.mock("@salesforce/community/basePath", () => ({ default: "/s" }), {
  virtual: true
});
jest.mock(
  "@salesforce/apex/HealthConnectPatientDashboardController.getDashboard",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/HealthConnectPatientDashboardController.ensurePatientForCurrentUser",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/HealthConnectPatientDashboardController.updatePatientProfile",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/HealthConnectDoctorPortalController.hasDoctorPortalAccess",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

function appendAndFlush(element) {
  document.body.appendChild(element);
  return Promise.resolve()
    .then(() => Promise.resolve())
    .then(() => Promise.resolve())
    .then(() => Promise.resolve())
    .then(() => Promise.resolve())
    .then(() => Promise.resolve());
}

describe("c-health-connect-patient-dashboard", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("shows the doctor dashboard instead of querying a patient record", async () => {
    hasDoctorPortalAccess.mockResolvedValue(true);
    const element = createElement("c-health-connect-patient-dashboard", {
      is: HealthConnectPatientDashboard
    });
    await appendAndFlush(element);

    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();

    expect(
      element.shadowRoot.querySelector("c-health-connect-doctor-dashboard")
    ).not.toBeNull();
    expect(ensurePatientForCurrentUser).not.toHaveBeenCalled();
    expect(getDashboard).not.toHaveBeenCalled();
  });

  it("ensures a Patient exists before loading the patient dashboard", async () => {
    hasDoctorPortalAccess.mockResolvedValue(false);
    ensurePatientForCurrentUser.mockResolvedValue();
    getDashboard.mockResolvedValue({
      patient: { Name: "Patient One", Patient_Status__c: "Active" },
      healthCases: [],
      immunizations: [],
      reminders: []
    });
    const element = createElement("c-health-connect-patient-dashboard", {
      is: HealthConnectPatientDashboard
    });
    await appendAndFlush(element);

    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();

    expect(ensurePatientForCurrentUser).toHaveBeenCalledTimes(1);
    expect(getDashboard).toHaveBeenCalledTimes(1);
    expect(
      ensurePatientForCurrentUser.mock.invocationCallOrder[0]
    ).toBeLessThan(getDashboard.mock.invocationCallOrder[0]);
  });

  it("does not load the dashboard when provisioning fails and retries on request", async () => {
    hasDoctorPortalAccess.mockResolvedValue(false);
    ensurePatientForCurrentUser
      .mockRejectedValueOnce({ body: { message: "Internal detail" } })
      .mockResolvedValueOnce();
    getDashboard.mockResolvedValue({
      patient: { Name: "Patient One", Patient_Status__c: "Active" },
      healthCases: [],
      immunizations: [],
      reminders: []
    });
    const element = createElement("c-health-connect-patient-dashboard", {
      is: HealthConnectPatientDashboard
    });
    await appendAndFlush(element);

    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();

    expect(getDashboard).not.toHaveBeenCalled();
    expect(element.shadowRoot.textContent).toContain("Please try again.");
    expect(element.shadowRoot.textContent).not.toContain("Internal detail");

    element.shadowRoot.querySelector("lightning-button").click();
    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();

    expect(ensurePatientForCurrentUser).toHaveBeenCalledTimes(2);
    expect(getDashboard).toHaveBeenCalledTimes(1);
  });

  it("shows pending care reminders in the notification menu", async () => {
    hasDoctorPortalAccess.mockResolvedValue(false);
    getDashboard.mockResolvedValue({
      patient: { Name: "Patient One", Patient_Status__c: "Active" },
      healthCases: [],
      immunizations: [],
      reminders: [
        {
          Id: "reminder-1",
          Reminder_Type__c: "Follow-up visit",
          Reminder_Status__c: "Pending",
          Due_Date__c: "2026-11-02"
        }
      ],
      upcomingAppointments: [],
      pastAppointments: [],
      undatedAppointments: [],
      healthCaseCount: 0,
      closedCaseCount: 0,
      appointmentCount: 0,
      upcomingAppointmentCount: 0,
      pendingReminderCount: 1,
      immunizationCount: 0
    });
    const element = createElement("c-health-connect-patient-dashboard", {
      is: HealthConnectPatientDashboard
    });
    await appendAndFlush(element);

    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();

    const notificationButton = element.shadowRoot.querySelector(
      ".notification-button"
    );
    expect(notificationButton.getAttribute("aria-label")).toContain(
      "1 pending"
    );
    expect(element.shadowRoot.querySelector(".notification-panel")).toBeNull();

    notificationButton.click();
    await Promise.resolve();
    await Promise.resolve();
    expect(element.shadowRoot.textContent).toContain("Care reminders");
    expect(element.shadowRoot.textContent).toContain("Follow-up visit");

    element.shadowRoot.querySelector(".notification-close").click();
    await Promise.resolve();
    expect(element.shadowRoot.querySelector(".notification-panel")).toBeNull();
  });

  it("shows upcoming immunizations that are in the loaded records", async () => {
    hasDoctorPortalAccess.mockResolvedValue(false);
    getDashboard.mockResolvedValue({
      patient: { Name: "Patient One", Patient_Status__c: "Active" },
      healthCases: [],
      immunizations: [
        {
          Id: "immunization-upcoming",
          Vaccine_Name__c: "Upcoming vaccine",
          Next_Due_Date__c: "2099-01-01"
        }
      ],
      reminders: [],
      upcomingAppointments: [],
      pastAppointments: [],
      undatedAppointments: [],
      healthCaseCount: 0,
      activeCaseCount: 0,
      closedCaseCount: 0,
      appointmentCount: 0,
      upcomingAppointmentCount: 0,
      pendingReminderCount: 0,
      immunizationCount: 1,
      upcomingImmunizationCount: 0
    });
    const element = createElement("c-health-connect-patient-dashboard", {
      is: HealthConnectPatientDashboard
    });
    await appendAndFlush(element);

    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();

    const upcomingImmunizationCard = [
      ...element.shadowRoot.querySelectorAll(".home-card")
    ].find((card) => card.textContent.includes("Upcoming immunizations"));
    expect(upcomingImmunizationCard.textContent).toContain("Upcoming vaccine");
    expect(upcomingImmunizationCard.textContent).not.toContain(
      "No upcoming immunization dates are recorded."
    );

    element.page = "immunizations";
    await Promise.resolve();
    await Promise.resolve();
    expect(element.shadowRoot.textContent).toContain("Upcoming vaccine");
  });

  it("shows the signed-in patient summary and their care records", async () => {
    hasDoctorPortalAccess.mockResolvedValue(false);
    getDashboard.mockResolvedValue({
      patient: {
        Name: "Patient One",
        Blood_Group__c: "O+",
        Patient_Status__c: "Active"
      },
      healthCases: [
        {
          Id: "case-1",
          Name: "HC-0001",
          CreatedDate: "2026-09-15T12:00:00.000Z",
          caseStatus: "Under Review",
          symptoms: "Persistent cough",
          diagnosis: "Upper respiratory infection",
          doctorRecommendation: "Rest and fluids",
          followUpDate: "2099-01-01",
          hasAssignedDoctor: true,
          assignedDoctorName: "Doctor One"
        },
        {
          Id: "case-2",
          Name: "HC-0002",
          caseStatus: "Closed"
        }
      ],
      immunizations: [
        {
          Id: "immunization-1",
          Vaccine_Name__c: "Example vaccine",
          Dose__c: "Dose 1",
          Date_Administered__c: "2026-09-01",
          Next_Due_Date__c: "2099-01-01"
        }
      ],
      reminders: [
        {
          Id: "reminder-1",
          Reminder_Type__c: "Follow-up",
          Reminder_Status__c: "Pending",
          Due_Date__c: "2026-10-20",
          Reminder_Notes__c: "Call the clinic to confirm"
        }
      ],
      upcomingAppointments: [
        {
          Id: "appointment-1",
          Name: "APT-0001",
          appointmentDate: "2026-10-22",
          appointmentStatus: "Scheduled",
          Appointment_Notes__c: "Internal note marker",
          hasAssignedDoctor: true,
          assignedDoctorName: "Dr. Test Doctor",
          relatedCaseName: "HC-0001",
          doctorRecommendation: "Rest and fluids"
        }
      ],
      cancelledAppointments: [
        {
          Id: "cancelled-appointment-1",
          Name: "APT-CANCELLED",
          appointmentDate: "2099-01-02",
          appointmentTime: "9:00 AM",
          appointmentStatus: "Cancelled",
          hasAssignedDoctor: false
        }
      ],
      pastAppointments: [],
      healthCaseCount: 2,
      activeCaseCount: 1,
      closedCaseCount: 1,
      pendingFollowUpCount: 1,
      appointmentCount: 2,
      upcomingAppointmentCount: 1,
      pendingReminderCount: 1,
      immunizationCount: 1,
      upcomingImmunizationCount: 1
    });
    const element = createElement("c-health-connect-patient-dashboard", {
      is: HealthConnectPatientDashboard
    });
    await appendAndFlush(element);

    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();

    expect(element.shadowRoot.textContent).toContain("Welcome, Patient One");
    expect(element.shadowRoot.querySelectorAll(".overview-link")).toHaveLength(
      4
    );
    expect(
      [...element.shadowRoot.querySelectorAll(".overview-link")].map((link) =>
        link.getAttribute("href").split("/").pop()
      )
    ).toEqual([
      "my-health",
      "appointments-cases",
      "appointments-cases",
      "my-immunizations"
    ]);
    expect(element.shadowRoot.textContent).toContain("Example vaccine");
    expect(element.shadowRoot.textContent).toContain("Immunization records");
    expect(element.shadowRoot.textContent).toContain("Recent recommendations");
    expect(element.shadowRoot.textContent).toContain("Active health cases");
    expect(element.shadowRoot.textContent).toContain("Open case follow-ups");
    expect(element.shadowRoot.textContent).toContain("Rest and fluids");
    expect(
      [...element.shadowRoot.querySelectorAll(".overview-value")].map(
        (value) => value.textContent
      )
    ).toEqual(["1", "1", "1", "1"]);

    element.page = "health";
    await Promise.resolve();
    await Promise.resolve();
    expect(element.shadowRoot.textContent).toContain(
      "Your health profile and history"
    );
    const caseButton = element.shadowRoot.querySelector(
      '[data-case-id="case-1"]'
    );
    expect(
      caseButton.querySelector(".case-record-copy .case-record-title")
        .textContent
    ).toBe("HC-0001");
    expect(
      caseButton.querySelectorAll(".case-record-meta .case-meta-item")
    ).toHaveLength(2);
    expect(caseButton.textContent).toContain("Diagnosis");
    expect(caseButton.textContent).toContain("Opened");
    caseButton.click();
    await Promise.resolve();
    await Promise.resolve();
    expect(
      element.shadowRoot.querySelector(".case-medical-details")
    ).not.toBeNull();
    expect(element.shadowRoot.textContent).toContain("Persistent cough");
    expect(element.shadowRoot.textContent).toContain(
      "Upper respiratory infection"
    );
    expect(element.shadowRoot.textContent).toContain("Rest and fluids");
    expect(element.shadowRoot.textContent).toContain("Doctor One");
    expect(element.shadowRoot.textContent).toContain("Follow-up date");
    expect(element.shadowRoot.textContent).not.toContain("Not provided");
    expect(element.shadowRoot.textContent).not.toContain(
      "No medication or prescription information is recorded"
    );

    element.shadowRoot.querySelector('[data-case-id="case-2"]').click();
    await Promise.resolve();
    await Promise.resolve();
    expect(element.shadowRoot.textContent).not.toContain(
      "No symptoms recorded."
    );
    expect(element.shadowRoot.textContent).not.toContain(
      "No diagnosis recorded."
    );
    expect(element.shadowRoot.textContent).not.toContain(
      "No recommendations recorded."
    );
    expect(
      element.shadowRoot
        .querySelector(".detail-panel")
        .querySelectorAll(".medical-field")
    ).toHaveLength(1);

    element.page = "immunizations";
    await Promise.resolve();
    await Promise.resolve();
    expect(element.shadowRoot.textContent).toContain("My Immunizations");
    element.shadowRoot
      .querySelector('[data-immunization-id="immunization-1"]')
      .click();
    await Promise.resolve();
    await Promise.resolve();
    expect(element.shadowRoot.textContent).toContain("IMMUNIZATION DETAILS");
    expect(element.shadowRoot.textContent).toContain("Next due date");

    element.page = "appointments";
    await Promise.resolve();
    await Promise.resolve();
    const scheduledCareSection = element.shadowRoot.querySelector(
      ".scheduled-care-section"
    );
    const appointmentHistorySection = element.shadowRoot.querySelector(
      ".appointment-history-section"
    );
    expect(scheduledCareSection.textContent).toContain("Upcoming appointments");
    expect(appointmentHistorySection.textContent).toContain(
      "Appointment history"
    );
    expect(
      scheduledCareSection.querySelector(
        '[data-appointment-id="appointment-1"]'
      )
    ).not.toBeNull();
    expect(
      appointmentHistorySection.querySelector(".appointment-history-filter")
    ).not.toBeNull();
    const followUpCard = element.shadowRoot.querySelector(".follow-up-card");
    expect(followUpCard.textContent).toContain("Follow-up date:");
    expect(followUpCard.textContent).toContain("Assigned doctor:");
    expect(followUpCard.textContent).toContain("Diagnosis:");
    expect(followUpCard.querySelectorAll("strong")).toHaveLength(3);
    const appointmentButton = element.shadowRoot.querySelector(
      '[data-appointment-id="appointment-1"]'
    );
    appointmentButton.click();
    await Promise.resolve();
    await Promise.resolve();
    expect(element.shadowRoot.textContent).not.toContain(
      "Internal note marker"
    );
    const appointmentDetail = element.shadowRoot.querySelector(
      "c-health-connect-appointment-detail"
    );
    expect(appointmentDetail).not.toBeNull();
    expect(appointmentDetail.parentElement).toBe(
      appointmentButton.parentElement
    );
    expect(appointmentDetail.shadowRoot.textContent).toContain(
      "Dr. Test Doctor"
    );
    expect(appointmentDetail.shadowRoot.textContent).toContain("HC-0001");
    expect(appointmentDetail.shadowRoot.textContent).toContain(
      "Doctor recommendation"
    );
    expect(appointmentDetail.shadowRoot.textContent).toContain(
      "Rest and fluids"
    );
    expect(element.shadowRoot.textContent).toContain("Cancelled appointments");
    element.shadowRoot
      .querySelector('[data-appointment-id="cancelled-appointment-1"]')
      .click();
    await Promise.resolve();
    await Promise.resolve();
    expect(element.shadowRoot.textContent).toContain("Cancelled");
    expect(getDashboard).toHaveBeenCalledTimes(1);
  });

  it("handles appointments with no assigned doctor or case recommendation", async () => {
    hasDoctorPortalAccess.mockResolvedValue(false);
    getDashboard.mockResolvedValue({
      patient: { Name: "Patient One", Patient_Status__c: "Active" },
      healthCases: [],
      immunizations: [],
      reminders: [],
      upcomingAppointments: [
        {
          Id: "appointment-without-details",
          Name: "APT-0002",
          appointmentDate: "2026-10-23",
          appointmentTime: "10:00 AM",
          appointmentStatus: "Scheduled",
          hasAssignedDoctor: false,
          assignedDoctorName: null,
          relatedCaseName: null,
          doctorRecommendation: null
        }
      ],
      pastAppointments: [],
      undatedAppointments: [],
      healthCaseCount: 0,
      closedCaseCount: 0,
      appointmentCount: 1,
      upcomingAppointmentCount: 1,
      pendingReminderCount: 0,
      immunizationCount: 0
    });
    const element = createElement("c-health-connect-patient-dashboard", {
      is: HealthConnectPatientDashboard
    });
    element.page = "appointments";
    await appendAndFlush(element);

    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();
    element.shadowRoot
      .querySelector('[data-appointment-id="appointment-without-details"]')
      .click();
    await Promise.resolve();
    await Promise.resolve();

    const appointmentDetail = element.shadowRoot.querySelector(
      "c-health-connect-appointment-detail"
    );
    expect(appointmentDetail.shadowRoot.textContent).toContain("APT-0002");
    expect(appointmentDetail.shadowRoot.textContent).not.toContain(
      "Assigned doctor"
    );
    expect(appointmentDetail.shadowRoot.textContent).not.toContain(
      "Doctor recommendation"
    );
    expect(appointmentDetail.shadowRoot.textContent).not.toContain("null");
  });

  it("shows overdue open appointments as missed visits with details", async () => {
    hasDoctorPortalAccess.mockResolvedValue(false);
    getDashboard.mockResolvedValue({
      patient: { Name: "Patient One", Patient_Status__c: "Active" },
      healthCases: [],
      immunizations: [],
      reminders: [],
      upcomingAppointments: [],
      missedAppointments: [
        {
          Id: "missed-appointment-1",
          Name: "APT-0003",
          appointmentDate: "2026-10-20",
          appointmentTime: "10:00 AM",
          appointmentStatus: "Scheduled",
          hasAssignedDoctor: true,
          assignedDoctorName: "Dr. Test Doctor",
          relatedCaseName: "HC-0003"
        }
      ],
      cancelledAppointments: [],
      pastAppointments: [],
      undatedAppointments: [],
      healthCaseCount: 0,
      appointmentCount: 1,
      upcomingAppointmentCount: 0,
      missedVisitCount: 1
    });
    const element = createElement("c-health-connect-patient-dashboard", {
      is: HealthConnectPatientDashboard
    });
    element.page = "appointments";
    await appendAndFlush(element);

    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();

    const followUpSection = element.shadowRoot.querySelector(
      ".appointment-follow-up-section"
    );
    const missedVisitsSection = element.shadowRoot.querySelector(
      ".missed-visits-section"
    );
    expect(followUpSection.compareDocumentPosition(missedVisitsSection)).toBe(
      Node.DOCUMENT_POSITION_FOLLOWING
    );
    expect(missedVisitsSection.textContent).toContain("Missed visits");
    expect(missedVisitsSection.textContent).toContain("1 missed");
    expect(missedVisitsSection.textContent).toContain("APT-0003");
    expect(missedVisitsSection.textContent).toContain("Dr. Test Doctor");
    expect(missedVisitsSection.textContent).toContain("HC-0003");

    missedVisitsSection
      .querySelector('[data-appointment-id="missed-appointment-1"]')
      .click();
    await Promise.resolve();
    await Promise.resolve();

    const appointmentDetail = missedVisitsSection.querySelector(
      "c-health-connect-appointment-detail"
    );
    expect(appointmentDetail).not.toBeNull();
    expect(appointmentDetail.shadowRoot.textContent).toContain("Missed visit");
    expect(appointmentDetail.shadowRoot.textContent).toContain(
      "Dr. Test Doctor"
    );
  });

  it("shows and updates only the signed-in patient's demographic profile", async () => {
    hasDoctorPortalAccess.mockResolvedValue(false);
    getDashboard.mockResolvedValue({
      patient: {
        Id: "patient-1",
        Name: "Patient One",
        Date_of_Birth__c: "1990-04-12",
        Phone_Number__c: "555-0100",
        Blood_Group__c: "O+",
        Gender__c: "Female",
        Address__c: "12 Example Road",
        State__c: "Example State",
        District__c: "Example District",
        Village__c: "Example Village"
      },
      healthCases: [],
      immunizations: [],
      reminders: [],
      upcomingAppointments: [],
      cancelledAppointments: [],
      pastAppointments: [],
      undatedAppointments: [],
      healthCaseCount: 0,
      activeCaseCount: 0,
      closedCaseCount: 0,
      pendingFollowUpCount: 0,
      appointmentCount: 0,
      upcomingAppointmentCount: 0,
      pendingReminderCount: 0,
      immunizationCount: 0,
      upcomingImmunizationCount: 0
    });
    const updatedPatient = {
      Id: "patient-1",
      Name: "Patient One",
      Date_of_Birth__c: "1990-04-12",
      Phone_Number__c: "555-0100",
      Blood_Group__c: "O+",
      Gender__c: "Female",
      Address__c: "34 New Example Road",
      State__c: "Example State",
      District__c: "Example District",
      Village__c: "Example Village"
    };
    updatePatientProfile.mockResolvedValue(updatedPatient);
    const element = createElement("c-health-connect-patient-dashboard", {
      is: HealthConnectPatientDashboard
    });
    await appendAndFlush(element);

    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();
    element.shadowRoot
      .querySelector(".account-chip-button")
      .dispatchEvent(new CustomEvent("click"));
    await Promise.resolve();
    await Promise.resolve();

    expect(element.shadowRoot.querySelector('[role="dialog"]')).not.toBeNull();
    expect(element.shadowRoot.textContent).toContain("Example Village");
    expect(element.shadowRoot.textContent).toContain("Example District");
    expect(element.shadowRoot.textContent).toContain("Example State");
    expect(element.shadowRoot.textContent).toContain("12 Example Road");
    expect(element.shadowRoot.textContent).toContain("Edit profile");

    element.shadowRoot.querySelector(".profile-primary-action").click();
    await Promise.resolve();
    await Promise.resolve();
    const addressField = element.shadowRoot.querySelector(
      'lightning-textarea[data-field="Address__c"]'
    );
    addressField.value = "34 New Example Road";
    addressField.dispatchEvent(new CustomEvent("change"));
    await Promise.resolve();
    element.shadowRoot
      .querySelector(".profile-primary-action")
      .dispatchEvent(new CustomEvent("click"));
    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();

    expect(updatePatientProfile).toHaveBeenCalledWith({
      patientName: "Patient One",
      dateOfBirth: "1990-04-12",
      phoneNumber: "555-0100",
      bloodGroup: "O+",
      gender: "Female",
      address: "34 New Example Road",
      state: "Example State",
      district: "Example District",
      village: "Example Village"
    });
    expect(element.shadowRoot.textContent).toContain(
      "Your profile has been updated."
    );
    expect(element.shadowRoot.textContent).toContain("34 New Example Road");
    expect(element.shadowRoot.querySelector("[data-case-id]")).toBeNull();
    expect(
      element.shadowRoot.querySelector("[data-appointment-id]")
    ).toBeNull();
  });

  it("filters completed appointment history by the selected date range", async () => {
    const dateDaysAgo = (days) => {
      const date = new Date();
      date.setDate(date.getDate() - days);
      const month = String(date.getMonth() + 1).padStart(2, "0");
      const day = String(date.getDate()).padStart(2, "0");
      return `${date.getFullYear()}-${month}-${day}`;
    };
    getDashboard.mockResolvedValue({
      patient: { Name: "Patient One", Patient_Status__c: "Active" },
      healthCases: [],
      immunizations: [],
      reminders: [],
      upcomingAppointments: [],
      pastAppointments: [5, 20, 40, 80, 100].map((days, index) => ({
        Id: `past-${days}`,
        Name: `APT-${index + 1}`,
        appointmentDate: dateDaysAgo(days),
        appointmentStatus: "Completed",
        hasAssignedDoctor: false
      })),
      undatedAppointments: [],
      healthCaseCount: 0,
      closedCaseCount: 0,
      appointmentCount: 5,
      upcomingAppointmentCount: 0,
      pendingReminderCount: 0,
      immunizationCount: 0
    });
    const element = createElement("c-health-connect-patient-dashboard", {
      is: HealthConnectPatientDashboard
    });
    element.page = "appointments";
    await appendAndFlush(element);

    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();

    const historyRows = () =>
      [...element.shadowRoot.querySelectorAll("[data-appointment-id]")].map(
        (row) => row.dataset.appointmentId
      );
    const filter = element.shadowRoot.querySelector(
      "lightning-combobox.appointment-history-filter"
    );

    expect(filter).not.toBeNull();
    expect(historyRows()).toEqual(["past-5", "past-20"]);

    const pastAppointment = element.shadowRoot.querySelector(
      '[data-appointment-id="past-5"]'
    );
    pastAppointment.click();
    await Promise.resolve();
    await Promise.resolve();
    const appointmentDetail = element.shadowRoot.querySelector(
      "c-health-connect-appointment-detail"
    );
    expect(appointmentDetail.parentElement).toBe(pastAppointment.parentElement);
    expect(appointmentDetail.shadowRoot.textContent).toContain("APT-1");

    filter.dispatchEvent(
      new CustomEvent("change", { detail: { value: "10days" } })
    );
    await Promise.resolve();
    await Promise.resolve();
    expect(historyRows()).toEqual(["past-5"]);

    filter.dispatchEvent(
      new CustomEvent("change", { detail: { value: "1month" } })
    );
    await Promise.resolve();
    await Promise.resolve();
    expect(historyRows()).toEqual(["past-5", "past-20"]);

    filter.dispatchEvent(
      new CustomEvent("change", { detail: { value: "3months" } })
    );
    await Promise.resolve();
    await Promise.resolve();
    expect(historyRows()).toEqual(["past-5", "past-20", "past-40", "past-80"]);
    expect(element.shadowRoot.textContent).toContain("Completed");
  });

  it("shows the requested portal sections and clearly describes unavailable messaging", async () => {
    getDashboard.mockResolvedValue({
      patient: { Name: "Patient One", Patient_Status__c: "Active" },
      healthCases: [
        {
          Id: "case-recommendation",
          Name: "HC-1001",
          caseStatus: "Under Review",
          doctorRecommendation: "Continue the prescribed care plan"
        }
      ],
      immunizations: [],
      reminders: [
        {
          Id: "reminder-message",
          Reminder_Type__c: "Follow-up",
          Reminder_Status__c: "Pending",
          Due_Date__c: "2026-10-30"
        }
      ],
      upcomingAppointments: [],
      pastAppointments: [],
      undatedAppointments: [],
      healthCaseCount: 1,
      closedCaseCount: 0,
      appointmentCount: 0,
      upcomingAppointmentCount: 0,
      pendingReminderCount: 1,
      immunizationCount: 0
    });
    const element = createElement("c-health-connect-patient-dashboard", {
      is: HealthConnectPatientDashboard
    });
    await appendAndFlush(element);

    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();

    expect(
      [...element.shadowRoot.querySelectorAll(".nav-item span")].map(
        (item) => item.textContent
      )
    ).toEqual([
      "Dashboard",
      "My Health",
      "My Immunizations",
      "Recommendations",
      "Appointments",
      "Help Center"
    ]);
    const navHrefs = [...element.shadowRoot.querySelectorAll(".nav-item")].map(
      (item) => item.getAttribute("href")
    );
    expect(navHrefs[0]).toMatch(/\/$/);
    expect(navHrefs[1]).toMatch(/\/my-health$/);
    expect(navHrefs[2]).toMatch(/\/my-immunizations$/);
    expect(navHrefs[3]).toMatch(/\/recommendations$/);
    expect(navHrefs[4]).toMatch(/\/appointments-cases$/);
    expect(navHrefs[5]).toMatch(/\/help-center$/);

    element.page = "recommendations";
    await Promise.resolve();
    await Promise.resolve();
    expect(element.shadowRoot.textContent).toContain(
      "Continue the prescribed care plan"
    );

    element.page = "messages";
    await Promise.resolve();
    await Promise.resolve();
    expect(element.shadowRoot.textContent).toContain(
      "Secure inbound messaging is not available"
    );
    expect(element.shadowRoot.textContent).toContain("Follow-up");

    element.page = "help";
    await Promise.resolve();
    await Promise.resolve();
    expect(element.shadowRoot.textContent).toContain("Help Center");
    expect(element.shadowRoot.textContent).toContain(
      "appointment booking are not currently available"
    );
  });

  it("shows an error when the patient dashboard cannot be loaded", async () => {
    getDashboard.mockRejectedValue({
      body: { message: "Internal Salesforce detail" }
    });
    const element = createElement("c-health-connect-patient-dashboard", {
      is: HealthConnectPatientDashboard
    });
    await appendAndFlush(element);

    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();

    expect(element.shadowRoot.textContent).toContain(
      "We could not prepare your patient profile or load your health information."
    );
    expect(element.shadowRoot.textContent).not.toContain(
      "Internal Salesforce detail"
    );
  });

  it("shows zero counts in the home overview when no records are available", async () => {
    getDashboard.mockResolvedValue({
      patient: {
        Name: "Patient One",
        Patient_Status__c: "Active"
      },
      healthCases: [],
      immunizations: [],
      reminders: [],
      upcomingAppointments: [],
      pastAppointments: [],
      undatedAppointments: [],
      healthCaseCount: 0,
      closedCaseCount: 0,
      appointmentCount: 0,
      upcomingAppointmentCount: 0,
      pendingReminderCount: 0,
      immunizationCount: 0
    });

    const element = createElement("c-health-connect-patient-dashboard", {
      is: HealthConnectPatientDashboard
    });
    await appendAndFlush(element);

    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();

    expect(
      [...element.shadowRoot.querySelectorAll(".overview-value")].map(
        (value) => value.textContent
      )
    ).toEqual(["0", "0", "0", "0"]);
  });

  it("shows a safe setup message when no patient is linked", async () => {
    getDashboard.mockResolvedValue({
      patientSetupPending: true,
      healthCases: [],
      immunizations: [],
      reminders: [],
      upcomingAppointments: [],
      pastAppointments: [],
      undatedAppointments: []
    });

    const element = createElement("c-health-connect-patient-dashboard", {
      is: HealthConnectPatientDashboard
    });
    await appendAndFlush(element);

    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();

    expect(element.shadowRoot.textContent).toContain(
      "Your patient profile is being prepared"
    );
    expect(element.shadowRoot.textContent).toContain(
      "A community health worker must verify"
    );
    expect(element.shadowRoot.querySelector(".patient-card")).toBeNull();
  });
});
