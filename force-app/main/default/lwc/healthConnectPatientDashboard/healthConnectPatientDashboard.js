import { api, LightningElement } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import communityBasePath from "@salesforce/community/basePath";
import isGuest from "@salesforce/user/isGuest";
import healthConnectLogo from "@salesforce/resourceUrl/HealthConnectLogo";
import healthConnectSymbol from "@salesforce/resourceUrl/HealthConnectSymbol";
import getDashboard from "@salesforce/apex/HealthConnectPatientDashboardController.getDashboard";
import ensurePatientForCurrentUser from "@salesforce/apex/HealthConnectPatientDashboardController.ensurePatientForCurrentUser";
import updatePatientProfile from "@salesforce/apex/HealthConnectPatientDashboardController.updatePatientProfile";
import hasDoctorPortalAccess from "@salesforce/apex/HealthConnectDoctorPortalController.hasDoctorPortalAccess";

export default class HealthConnectPatientDashboard extends NavigationMixin(
  LightningElement
) {
  dashboard;
  errorMessage;
  @api page = "home";
  isDoctorPortalUser = false;
  portalResolved = false;
  selectedCaseId;
  selectedAppointmentId;
  selectedImmunizationId;
  selectedAppointmentHistoryPeriod = "30days";
  showNotifications = false;
  showPatientProfile = false;
  isEditingPatientProfile = false;
  isSavingPatientProfile = false;
  patientProfileDraft;
  profileErrorMessage;
  profileSuccessMessage;
  profileDialogWasOpen = false;
  isGuestUser = isGuest;
  logoUrl = healthConnectLogo;
  symbolUrl = healthConnectSymbol;

  connectedCallback() {
    if (!this.isGuestUser) {
      this.loadPortal();
    }
  }

  renderedCallback() {
    if (this.showPatientProfile && !this.profileDialogWasOpen) {
      this.profileDialogWasOpen = true;
      this.template.querySelector(".patient-profile-dialog")?.focus();
    } else if (!this.showPatientProfile && this.profileDialogWasOpen) {
      this.profileDialogWasOpen = false;
      this.template.querySelector(".account-chip-button")?.focus();
    }
  }

  async loadPortal() {
    try {
      this.isDoctorPortalUser = await hasDoctorPortalAccess();
      if (!this.isDoctorPortalUser) {
        await ensurePatientForCurrentUser();
        this.dashboard = await getDashboard();
      }
      this.errorMessage = undefined;
    } catch {
      this.dashboard = undefined;
      this.errorMessage =
        "We could not prepare your patient profile or load your health information. Please try again.";
    } finally {
      this.portalResolved = true;
    }
  }

  async handleRetry() {
    this.portalResolved = false;
    this.errorMessage = undefined;
    await this.loadPortal();
  }

  get loginUrl() {
    return `${communityBasePath}/login`;
  }

  get homeUrl() {
    return `${communityBasePath}/`;
  }

  get patient() {
    return this.dashboard?.patient;
  }

  get isHomePage() {
    return this.page === "home";
  }

  get isMyHealthPage() {
    return this.page === "health";
  }

  get isImmunizationsPage() {
    return this.page === "immunizations";
  }

  get isRecommendationsPage() {
    return this.page === "recommendations";
  }

  get isAppointmentsPage() {
    return this.page === "appointments";
  }

  get isMessagesPage() {
    return this.page === "messages";
  }

  get isHelpPage() {
    return this.page === "help";
  }

  get navItems() {
    return [
      {
        label: "Dashboard",
        page: "home",
        href: `${communityBasePath}/`,
        icon: "utility:home"
      },
      {
        label: "My Health",
        page: "health",
        href: `${communityBasePath}/my-health`,
        icon: "utility:heart"
      },
      {
        label: "My Immunizations",
        page: "immunizations",
        href: `${communityBasePath}/my-immunizations`,
        icon: "utility:shield"
      },
      {
        label: "Recommendations",
        page: "recommendations",
        href: `${communityBasePath}/recommendations`,
        icon: "utility:light_bulb"
      },
      {
        label: "Appointments",
        page: "appointments",
        href: `${communityBasePath}/appointments-cases`,
        icon: "utility:event"
      },
      {
        label: "Help Center",
        page: "help",
        href: `${communityBasePath}/help-center`,
        icon: "utility:question"
      }
    ].map((item) => ({
      ...item,
      isCurrent: item.page === this.page,
      ariaCurrent: item.page === this.page ? "page" : undefined,
      className: `nav-item${item.page === this.page ? " nav-item-current" : ""}`
    }));
  }

  get accountLabel() {
    return this.isDoctorPortalUser
      ? "Doctor workspace"
      : this.patient?.Name || "My account";
  }

  get canEditPatientProfile() {
    return !this.isDoctorPortalUser && Boolean(this.patient?.Id);
  }

  get profileButtonLabel() {
    return `Open profile for ${this.accountLabel}`;
  }

  get genderOptions() {
    return [
      { label: "Select gender", value: "" },
      { label: "Male", value: "Male" },
      { label: "Female", value: "Female" },
      { label: "Other", value: "Other" },
      { label: "Prefer not to say", value: "Prefer not to say" },
      { label: "Unknown", value: "Unknown" }
    ];
  }

  get bloodGroupOptions() {
    return [
      { label: "Select blood group", value: "" },
      ...["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-", "Unknown"].map(
        (value) => ({ label: value, value })
      )
    ];
  }

  get notificationCount() {
    return this.dashboard?.pendingReminderCount || 0;
  }

  get hasNotifications() {
    return this.notificationCount > 0;
  }

  get hasNotificationItems() {
    return this.notificationItems.length > 0;
  }

  get notificationItems() {
    return (this.dashboard?.reminders || [])
      .filter((reminder) => reminder.Reminder_Status__c === "Pending")
      .slice(0, 4);
  }

  get notificationButtonLabel() {
    return this.hasNotifications
      ? `Notifications, ${this.notificationCount} pending care reminders`
      : "Notifications, no pending care reminders";
  }

  toggleNotifications() {
    this.showNotifications = !this.showNotifications;
  }

  closeNotifications() {
    this.showNotifications = false;
  }

  openPatientProfile() {
    if (!this.canEditPatientProfile) {
      return;
    }
    this.showNotifications = false;
    this.showPatientProfile = true;
    this.profileErrorMessage = undefined;
    this.profileSuccessMessage = undefined;
  }

  closePatientProfile() {
    if (this.isSavingPatientProfile) {
      return;
    }
    this.showPatientProfile = false;
    this.isEditingPatientProfile = false;
    this.patientProfileDraft = undefined;
    this.profileErrorMessage = undefined;
  }

  startEditingPatientProfile() {
    if (!this.canEditPatientProfile || this.isSavingPatientProfile) {
      return;
    }
    this.patientProfileDraft = {
      Name: this.patient.Name || "",
      Date_of_Birth__c: this.patient.Date_of_Birth__c || "",
      Phone_Number__c: this.patient.Phone_Number__c || "",
      Blood_Group__c: this.patient.Blood_Group__c || "",
      Gender__c: this.patient.Gender__c || "",
      Address__c: this.patient.Address__c || "",
      State__c: this.patient.State__c || "",
      District__c: this.patient.District__c || "",
      Village__c: this.patient.Village__c || ""
    };
    this.profileErrorMessage = undefined;
    this.profileSuccessMessage = undefined;
    this.isEditingPatientProfile = true;
  }

  cancelEditingPatientProfile() {
    this.patientProfileDraft = undefined;
    this.profileErrorMessage = undefined;
    this.isEditingPatientProfile = false;
  }

  handlePatientProfileFieldChange(event) {
    const field = event.target.dataset.field;
    this.patientProfileDraft = {
      ...this.patientProfileDraft,
      [field]: event.target.value
    };
  }

  async savePatientProfile() {
    if (!this.canEditPatientProfile || this.isSavingPatientProfile) {
      return;
    }
    if (!this.patientProfileDraft?.Name?.trim()) {
      this.profileErrorMessage = "Name is required.";
      return;
    }
    this.isSavingPatientProfile = true;
    this.profileErrorMessage = undefined;
    this.profileSuccessMessage = undefined;
    try {
      const updatedPatient = await updatePatientProfile({
        patientName: this.patientProfileDraft.Name,
        dateOfBirth: this.patientProfileDraft.Date_of_Birth__c || null,
        phoneNumber: this.patientProfileDraft.Phone_Number__c || null,
        bloodGroup: this.patientProfileDraft.Blood_Group__c || null,
        gender: this.patientProfileDraft.Gender__c || null,
        address: this.patientProfileDraft.Address__c || null,
        state: this.patientProfileDraft.State__c || null,
        district: this.patientProfileDraft.District__c || null,
        village: this.patientProfileDraft.Village__c || null
      });
      this.dashboard = { ...this.dashboard, patient: updatedPatient };
      this.patientProfileDraft = undefined;
      this.isEditingPatientProfile = false;
      this.profileSuccessMessage = "Your profile has been updated.";
    } catch (error) {
      this.profileErrorMessage =
        error?.body?.message ||
        "We could not save your profile. Please review your details and try again.";
    } finally {
      this.isSavingPatientProfile = false;
    }
  }

  handlePatientProfileKeydown(event) {
    if (event.key === "Escape" && !this.isSavingPatientProfile) {
      event.stopPropagation();
      this.closePatientProfile();
    }
  }

  handleLogout() {
    this[NavigationMixin.Navigate]({
      type: "comm__loginPage",
      attributes: { actionName: "logout" }
    });
  }

  get myHealthUrl() {
    return `${communityBasePath}/my-health`;
  }

  get immunizationsUrl() {
    return `${communityBasePath}/my-immunizations`;
  }

  get appointmentsUrl() {
    return `${communityBasePath}/appointments-cases`;
  }

  get recommendationsUrl() {
    return `${communityBasePath}/recommendations`;
  }

  get messagesUrl() {
    return `${communityBasePath}/messages`;
  }

  get helpCenterUrl() {
    return `${communityBasePath}/help-center`;
  }

  get homeAriaCurrent() {
    return this.isHomePage ? "page" : undefined;
  }

  get healthAriaCurrent() {
    return this.isMyHealthPage ? "page" : undefined;
  }

  get immunizationsAriaCurrent() {
    return this.isImmunizationsPage ? "page" : undefined;
  }

  get recommendationsAriaCurrent() {
    return this.isRecommendationsPage ? "page" : undefined;
  }

  get appointmentsAriaCurrent() {
    return this.isAppointmentsPage ? "page" : undefined;
  }

  get messagesAriaCurrent() {
    return this.isMessagesPage ? "page" : undefined;
  }

  get helpAriaCurrent() {
    return this.isHelpPage ? "page" : undefined;
  }

  get isPatientSetupPending() {
    return this.dashboard?.patientSetupPending;
  }

  get isLoading() {
    return (
      !this.isGuestUser &&
      (!this.portalResolved || (!this.isDoctorPortalUser && !this.dashboard)) &&
      !this.errorMessage
    );
  }

  get hasImmunizations() {
    return Boolean(this.dashboard?.immunizations?.length);
  }

  get hasHealthCases() {
    return Boolean(this.dashboard?.healthCases?.length);
  }

  get hasReminders() {
    return Boolean(this.dashboard?.reminders?.length);
  }

  get hasAppointments() {
    return Boolean(
      this.dashboard?.appointmentCount ||
      this.dashboard?.upcomingAppointments?.length ||
      this.dashboard?.missedAppointments?.length ||
      this.dashboard?.cancelledAppointments?.length ||
      this.dashboard?.pastAppointments?.length ||
      this.dashboard?.undatedAppointments?.length
    );
  }

  get hasCancelledAppointments() {
    return Boolean(this.dashboard?.cancelledAppointments?.length);
  }

  get hasUpcomingAppointments() {
    return Boolean(this.dashboard?.upcomingAppointments?.length);
  }

  get missedVisitCount() {
    return this.dashboard?.missedVisitCount || 0;
  }

  get missedVisitRows() {
    return this.withAppointmentDisplayValues(
      this.dashboard?.missedAppointments
    ).map((appointment) => ({
      ...appointment,
      appointmentStatus: "Missed visit",
      statusBadgeClass: "record-status status-negative"
    }));
  }

  get hasMissedVisits() {
    return this.missedVisitCount > 0;
  }

  get hasMoreMissedVisits() {
    return this.missedVisitCount > this.missedVisitRows.length;
  }

  get hasPastAppointments() {
    return this.pastAppointmentRows.length > 0;
  }

  get hasUndatedAppointments() {
    return Boolean(this.dashboard?.undatedAppointments?.length);
  }

  get hasAppointmentHistoryRecords() {
    return (
      Boolean(this.dashboard?.pastAppointments?.length) ||
      this.hasCancelledAppointments ||
      this.hasUndatedAppointments
    );
  }

  get showEmptyAppointmentHistory() {
    return (
      !this.hasPastAppointments &&
      !this.hasCancelledAppointments &&
      !this.hasUndatedAppointments
    );
  }

  get caseRows() {
    return (this.dashboard?.healthCases || []).map((healthCase) => ({
      ...healthCase,
      statusBadgeClass: this.statusBadgeClass(healthCase.caseStatus),
      isSelected: healthCase.Id === this.selectedCaseId
    }));
  }

  get activeCaseRows() {
    return (this.dashboard?.healthCases || [])
      .filter((healthCase) => healthCase.caseStatus !== "Closed")
      .slice(0, 3);
  }

  get activeCaseCount() {
    return this.dashboard?.activeCaseCount || 0;
  }

  get hasActiveCases() {
    return this.activeCaseCount > 0;
  }

  get upcomingImmunizationRows() {
    const today = this.toDateOnlyString(new Date());
    return (this.dashboard?.immunizations || []).filter(
      (item) => item.Next_Due_Date__c && item.Next_Due_Date__c >= today
    );
  }

  get upcomingImmunizationCount() {
    return this.dashboard?.upcomingImmunizationCount || 0;
  }

  get hasUpcomingImmunizations() {
    return this.upcomingImmunizationRows.length > 0;
  }

  get hasMoreUpcomingImmunizations() {
    return (
      this.upcomingImmunizationCount > this.upcomingImmunizationRows.length
    );
  }

  get recommendationRows() {
    return (this.dashboard?.healthCases || [])
      .filter(
        (healthCase) =>
          typeof healthCase.doctorRecommendation === "string" &&
          healthCase.doctorRecommendation.trim().length > 0
      )
      .map((healthCase) => ({
        ...healthCase,
        statusBadgeClass: this.statusBadgeClass(healthCase.caseStatus)
      }));
  }

  get recentRecommendationRows() {
    return this.recommendationRows.slice(0, 3);
  }

  get hasRecommendations() {
    return this.recommendationRows.length > 0;
  }

  get followUpRows() {
    const today = this.toDateOnlyString(new Date());
    return (this.dashboard?.healthCases || [])
      .filter(
        (healthCase) =>
          healthCase.followUpDate && healthCase.caseStatus !== "Closed"
      )
      .sort((first, second) =>
        first.followUpDate.localeCompare(second.followUpDate)
      )
      .map((healthCase) => ({
        ...healthCase,
        followUpState:
          healthCase.followUpDate < today ? "Date passed" : "Scheduled",
        statusBadgeClass:
          healthCase.followUpDate < today
            ? "record-status status-warning"
            : "record-status status-positive"
      }));
  }

  get hasFollowUps() {
    return this.followUpRows.length > 0;
  }

  get hasMoreFollowUps() {
    return this.pendingFollowUpCount > this.followUpRows.length;
  }

  get immunizationRows() {
    return (this.dashboard?.immunizations || []).map((item) => ({
      ...item,
      nextDoseLabel: item.Next_Due_Date__c
        ? "Next dose date recorded"
        : "No next dose date recorded",
      isSelected: item.Id === this.selectedImmunizationId
    }));
  }

  get selectedImmunization() {
    return this.dashboard?.immunizations?.find(
      (item) => item.Id === this.selectedImmunizationId
    );
  }

  get upcomingAppointmentRows() {
    return this.withAppointmentDisplayValues(
      this.dashboard?.upcomingAppointments
    );
  }

  get homeUpcomingAppointmentRows() {
    return this.upcomingAppointmentRows.slice(0, 3);
  }

  get cancelledAppointmentRows() {
    return this.withAppointmentDisplayValues(
      this.dashboard?.cancelledAppointments
    );
  }

  get pastAppointmentRows() {
    const historyStartDate = this.appointmentHistoryStartDate;
    const appointments = (this.dashboard?.pastAppointments || []).filter(
      (appointment) =>
        appointment.appointmentDate &&
        appointment.appointmentDate >= historyStartDate
    );
    return this.withAppointmentDisplayValues(appointments);
  }

  get appointmentHistoryOptions() {
    return [
      { label: "Past 10 days", value: "10days" },
      { label: "Past 30 days", value: "30days" },
      { label: "Past 1 month", value: "1month" },
      { label: "Past 3 months", value: "3months" }
    ];
  }

  get appointmentHistoryStartDate() {
    const today = new Date();
    const startDate = new Date(
      today.getFullYear(),
      today.getMonth(),
      today.getDate()
    );
    if (this.selectedAppointmentHistoryPeriod === "10days") {
      startDate.setDate(startDate.getDate() - 10);
    } else if (this.selectedAppointmentHistoryPeriod === "1month") {
      return this.calendarMonthsAgo(startDate, 1);
    } else if (this.selectedAppointmentHistoryPeriod === "3months") {
      return this.calendarMonthsAgo(startDate, 3);
    } else {
      startDate.setDate(startDate.getDate() - 30);
    }
    return this.toDateOnlyString(startDate);
  }

  calendarMonthsAgo(date, months) {
    const targetMonth = new Date(
      date.getFullYear(),
      date.getMonth() - months,
      1
    );
    const lastDayOfTargetMonth = new Date(
      targetMonth.getFullYear(),
      targetMonth.getMonth() + 1,
      0
    ).getDate();
    targetMonth.setDate(Math.min(date.getDate(), lastDayOfTargetMonth));
    return this.toDateOnlyString(targetMonth);
  }

  toDateOnlyString(date) {
    const month = String(date.getMonth() + 1).padStart(2, "0");
    const day = String(date.getDate()).padStart(2, "0");
    return `${date.getFullYear()}-${month}-${day}`;
  }

  get undatedAppointmentRows() {
    return this.withAppointmentDisplayValues(
      this.dashboard?.undatedAppointments
    );
  }

  get selectedCase() {
    const healthCase = this.dashboard?.healthCases?.find(
      (item) => item.Id === this.selectedCaseId
    );
    return healthCase
      ? {
          ...healthCase,
          statusBadgeClass: this.statusBadgeClass(healthCase.caseStatus)
        }
      : undefined;
  }

  get hasMoreCases() {
    return (
      (this.dashboard?.healthCaseCount || 0) >
      (this.dashboard?.healthCases?.length || 0)
    );
  }

  get hasMoreAppointments() {
    const displayed =
      (this.dashboard?.upcomingAppointments?.length || 0) +
      (this.dashboard?.missedAppointments?.length || 0) +
      (this.dashboard?.cancelledAppointments?.length || 0) +
      (this.dashboard?.pastAppointments?.length || 0) +
      (this.dashboard?.undatedAppointments?.length || 0);
    return (this.dashboard?.appointmentCount || 0) > displayed;
  }

  get hasMoreImmunizations() {
    return (
      (this.dashboard?.immunizationCount || 0) >
      (this.dashboard?.immunizations?.length || 0)
    );
  }

  get immunizationCount() {
    return this.dashboard?.immunizationCount || 0;
  }

  get appointmentCount() {
    return this.dashboard?.appointmentCount || 0;
  }

  get healthCaseCount() {
    return this.dashboard?.healthCaseCount || 0;
  }

  get closedCaseCount() {
    return this.dashboard?.closedCaseCount || 0;
  }

  get upcomingAppointmentCount() {
    return this.dashboard?.upcomingAppointmentCount || 0;
  }

  get pendingReminderCount() {
    return this.dashboard?.pendingReminderCount || 0;
  }

  get pendingFollowUpCount() {
    return this.dashboard?.pendingFollowUpCount || 0;
  }

  statusBadgeClass(status) {
    const normalizedStatus = (status || "").toLowerCase();
    if (["cancelled", "canceled", "rejected"].includes(normalizedStatus)) {
      return "record-status status-negative";
    }
    if (["missed", "no show", "no-show"].includes(normalizedStatus)) {
      return "record-status status-negative";
    }
    if (["completed", "closed"].includes(normalizedStatus)) {
      return "record-status status-neutral";
    }
    if (
      ["scheduled", "rescheduled", "new", "active"].includes(normalizedStatus)
    ) {
      return "record-status status-positive";
    }
    if (
      ["pending", "under review", "in progress", "on hold"].includes(
        normalizedStatus
      )
    ) {
      return "record-status status-warning";
    }
    return "record-status status-neutral";
  }

  handleCaseSelect(event) {
    const selectedId = event.currentTarget.dataset.caseId;
    this.selectedCaseId =
      this.selectedCaseId === selectedId ? undefined : selectedId;
    this.selectedAppointmentId = undefined;
    this.selectedImmunizationId = undefined;
  }

  clearCaseSelection() {
    this.selectedCaseId = undefined;
  }

  handleAppointmentSelect(event) {
    const selectedId = event.currentTarget.dataset.appointmentId;
    this.selectedAppointmentId =
      this.selectedAppointmentId === selectedId ? undefined : selectedId;
    this.selectedCaseId = undefined;
    this.selectedImmunizationId = undefined;
  }

  handleAppointmentHistoryPeriodChange(event) {
    this.selectedAppointmentHistoryPeriod = event.detail.value;
    this.selectedAppointmentId = undefined;
  }

  clearAppointmentSelection() {
    this.selectedAppointmentId = undefined;
  }

  handleImmunizationSelect(event) {
    const selectedId = event.currentTarget.dataset.immunizationId;
    this.selectedImmunizationId =
      this.selectedImmunizationId === selectedId ? undefined : selectedId;
    this.selectedCaseId = undefined;
    this.selectedAppointmentId = undefined;
  }

  clearImmunizationSelection() {
    this.selectedImmunizationId = undefined;
  }

  withAppointmentDisplayValues(appointments = []) {
    return appointments.map((appointment) => ({
      ...appointment,
      statusBadgeClass: this.statusBadgeClass(appointment.appointmentStatus),
      isSelected: appointment.Id === this.selectedAppointmentId,
      detailsId: `appointment-details-${appointment.Id}`
    }));
  }
}
