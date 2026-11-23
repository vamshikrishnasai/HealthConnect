import { LightningElement } from "lwc";
import getAssignedAppointments from "@salesforce/apex/HealthConnectDoctorPortalController.getAssignedAppointments";
import getAssignedCases from "@salesforce/apex/HealthConnectDoctorPortalController.getAssignedCases";
import saveCaseReviewAction from "@salesforce/apex/HealthConnectDoctorPortalController.saveCaseReview";
import getCurrentDoctorProfile from "@salesforce/apex/HealthConnectDoctorProfileController.getCurrentDoctorProfile";
import saveCurrentDoctorProfile from "@salesforce/apex/HealthConnectDoctorProfileController.saveCurrentDoctorProfile";
import healthConnectLogo from "@salesforce/resourceUrl/HealthConnectLogo";

const CASE_STATUS_OPTIONS = [
  { label: "New", value: "New" },
  { label: "Under Review", value: "Under Review" },
  { label: "Recommendation Provided", value: "Recommendation Provided" },
  { label: "Follow-up Required", value: "Follow-up Required" },
  { label: "Closed", value: "Closed" }
];

const SPECIALIZATION_OPTIONS = [
  { label: "Select specialization", value: "" },
  { label: "General Physician", value: "General Physician" },
  { label: "Pediatrician", value: "Pediatrician" },
  { label: "Cardiologist", value: "Cardiologist" },
  { label: "Dermatologist", value: "Dermatologist" },
  { label: "Other", value: "Other" }
];

const AVAILABILITY_OPTIONS = [
  { label: "Select availability", value: "" },
  { label: "Available", value: "Available" },
  { label: "Unavailable", value: "Unavailable" }
];

const mapDoctorProfile = (profile) => ({
  ...profile,
  specializationLabel: profile.specialization || "Not provided",
  facilityLabel: profile.healthcareFacility || "Not provided",
  districtLabel: profile.district || "Not provided",
  availabilityLabel: profile.availabilityStatus || "Not provided",
  emailLabel: profile.email || "Not provided",
  phoneLabel: profile.phoneNumber || "Not provided"
});

const makeProfileDraft = (profile = {}) => ({
  phoneNumber: profile.phoneNumber || "",
  specialization: profile.specialization || "",
  healthcareFacility: profile.healthcareFacility || "",
  district: profile.district || "",
  availabilityStatus: profile.availabilityStatus || "",
  specializationOptions: SPECIALIZATION_OPTIONS.map((option) => ({
    ...option,
    selected: option.value === (profile.specialization || "")
  })),
  availabilityOptions: AVAILABILITY_OPTIONS.map((option) => ({
    ...option,
    selected: option.value === (profile.availabilityStatus || "")
  }))
});

const formatDate = (value) => {
  if (!value) {
    return "Not recorded";
  }
  const date = new Date(`${value}T00:00:00`);
  return new Intl.DateTimeFormat().format(date);
};

const formatDateTime = (value) => {
  if (!value) {
    return "Not recorded";
  }
  return new Intl.DateTimeFormat(undefined, {
    dateStyle: "medium",
    timeStyle: "short"
  }).format(new Date(value));
};

const getErrorMessage = (error) =>
  error?.body?.message ||
  error?.message ||
  "An unexpected error occurred. Please try again.";

const getCaseStatusClass = (status) => {
  switch (status) {
    case "Recommendation Provided":
      return "status-pill status-pill--success";
    case "Follow-up Required":
      return "status-pill status-pill--follow-up";
    case "Closed":
      return "status-pill status-pill--closed";
    case "Under Review":
      return "status-pill status-pill--review";
    default:
      return "status-pill";
  }
};

export default class HealthConnectDoctorDashboard extends LightningElement {
  cases = [];
  appointments = [];
  doctorProfile;
  doctorProfileError;
  profileDraft = makeProfileDraft();
  profileSaveError;
  profileSaveMessage;
  isProfileOpen = false;
  isEditingProfile = false;
  isSavingProfile = false;
  portalUserName = "Doctor";
  errorMessage;
  isLoading = true;
  healthConnectLogoUrl = healthConnectLogo;

  connectedCallback() {
    this.loadDashboard();
  }

  get hasCases() {
    return this.cases.length > 0;
  }

  get hasAppointments() {
    return this.appointments.length > 0;
  }

  get caseCount() {
    return this.cases.length;
  }

  get appointmentCount() {
    return this.appointments.length;
  }

  get doctorName() {
    return this.doctorProfile?.name || this.portalUserName;
  }

  async loadDashboard() {
    this.isLoading = true;
    this.errorMessage = undefined;
    try {
      const [assignedCases, assignedAppointments] = await Promise.all([
        getAssignedCases(),
        getAssignedAppointments()
      ]);
      this.cases = assignedCases.map((caseRecord) => ({
        ...caseRecord,
        statusOptions: CASE_STATUS_OPTIONS.map((option) => ({
          ...option,
          selected: option.value === caseRecord.caseStatus
        })),
        statusClass: getCaseStatusClass(caseRecord.caseStatus),
        diagnosisDraft: caseRecord.diagnosis || "",
        recommendationDraft: caseRecord.recommendation || "",
        caseStatusDraft: caseRecord.caseStatus,
        appointmentRequiredDraft: Boolean(caseRecord.appointmentRequired),
        followUpDateDraft: caseRecord.followUpDate || "",
        patientDateOfBirthLabel: formatDate(caseRecord.patientDateOfBirth),
        createdDateLabel: formatDateTime(caseRecord.createdDate),
        followUpDateLabel: formatDate(caseRecord.followUpDate),
        patientPhoneNumberLabel:
          caseRecord.patientPhoneNumber || "Not recorded",
        symptomsLabel: caseRecord.symptoms || "No symptoms recorded",
        diagnosisLabel: caseRecord.diagnosis || "No diagnosis recorded",
        recommendationLabel:
          caseRecord.recommendation || "No recommendation recorded",
        appointmentRequiredLabel: caseRecord.appointmentRequired
          ? "Required"
          : "Not required",
        lastModifiedDate: caseRecord.lastModifiedDate,
        hasSavedReview: Boolean(
          caseRecord.diagnosis ||
          caseRecord.recommendation ||
          caseRecord.followUpDate ||
          caseRecord.appointmentRequired ||
          caseRecord.caseStatus !== "New"
        ),
        isEditing: !(
          caseRecord.diagnosis ||
          caseRecord.recommendation ||
          caseRecord.followUpDate ||
          caseRecord.appointmentRequired ||
          caseRecord.caseStatus !== "New"
        ),
        saveMessage: "",
        saveMessageClass: "",
        saveMessageRole: "status",
        isSaving: false
      }));
      this.appointments = assignedAppointments.map((appointment) => ({
        ...appointment,
        appointmentDateLabel: formatDate(appointment.appointmentDate),
        appointmentTimeLabel: appointment.appointmentTime || "Not recorded",
        caseNameLabel: appointment.caseName || "Not linked to a case",
        notesLabel: appointment.notes || "No appointment notes"
      }));
      try {
        const doctorProfile = await getCurrentDoctorProfile();
        this.portalUserName = doctorProfile.name || "Doctor";
        if (doctorProfile.profileError) {
          this.doctorProfile = undefined;
          this.doctorProfileError = doctorProfile.profileError;
        } else {
          this.doctorProfileError = undefined;
          this.doctorProfile = mapDoctorProfile(doctorProfile);
          this.profileDraft = makeProfileDraft(doctorProfile);
        }
      } catch (profileError) {
        this.doctorProfile = undefined;
        this.doctorProfileError = getErrorMessage(profileError);
        this.portalUserName = "Doctor";
      }
    } catch (error) {
      this.cases = [];
      this.appointments = [];
      this.doctorProfile = undefined;
      this.doctorProfileError = undefined;
      this.errorMessage = getErrorMessage(error);
    } finally {
      this.isLoading = false;
    }
  }

  toggleProfile() {
    this.isProfileOpen = !this.isProfileOpen;
    this.profileSaveError = undefined;
    this.profileSaveMessage = undefined;
    if (!this.isProfileOpen) {
      this.cancelProfileEdit();
    }
  }

  editProfile() {
    this.profileDraft = makeProfileDraft(this.doctorProfile);
    this.profileSaveError = undefined;
    this.profileSaveMessage = undefined;
    this.isEditingProfile = true;
  }

  handleProfileFieldChange(event) {
    const fieldName = event.currentTarget.dataset.field;
    const value = event.target.value;
    const changes = { [fieldName]: value };
    if (fieldName === "specialization") {
      changes.specializationOptions = SPECIALIZATION_OPTIONS.map((option) => ({
        ...option,
        selected: option.value === value
      }));
    } else if (fieldName === "availabilityStatus") {
      changes.availabilityOptions = AVAILABILITY_OPTIONS.map((option) => ({
        ...option,
        selected: option.value === value
      }));
    }
    this.profileDraft = { ...this.profileDraft, ...changes };
    this.profileSaveError = undefined;
    this.profileSaveMessage = undefined;
  }

  cancelProfileEdit() {
    this.profileDraft = makeProfileDraft(this.doctorProfile);
    this.profileSaveError = undefined;
    this.isEditingProfile = false;
  }

  async saveProfile() {
    this.isSavingProfile = true;
    this.profileSaveError = undefined;
    this.profileSaveMessage = undefined;
    try {
      const savedProfile = await saveCurrentDoctorProfile({
        phoneNumber: this.profileDraft.phoneNumber,
        specialization: this.profileDraft.specialization,
        healthcareFacility: this.profileDraft.healthcareFacility,
        district: this.profileDraft.district,
        availabilityStatus: this.profileDraft.availabilityStatus
      });
      this.doctorProfile = mapDoctorProfile(savedProfile);
      this.portalUserName = savedProfile.name || "Doctor";
      this.profileDraft = makeProfileDraft(savedProfile);
      this.isEditingProfile = false;
      this.profileSaveMessage = "Profile updated successfully.";
    } catch (error) {
      this.profileSaveError = getErrorMessage(error);
    } finally {
      this.isSavingProfile = false;
    }
  }

  handleCaseFieldChange(event) {
    const caseId = event.currentTarget.dataset.caseId;
    const fieldName = event.currentTarget.dataset.field;
    const value =
      fieldName === "appointmentRequiredDraft"
        ? event.target.checked
        : event.target.value;
    const changes = {
      [fieldName]: value,
      saveMessage: "",
      saveMessageClass: "",
      saveMessageRole: "status"
    };
    if (fieldName === "caseStatusDraft") {
      changes.statusOptions = CASE_STATUS_OPTIONS.map((option) => ({
        ...option,
        selected: option.value === value
      }));
    }
    this.updateCase(caseId, {
      ...changes
    });
  }

  editCaseReview(event) {
    const caseId = event.currentTarget.dataset.caseId;
    this.updateCase(caseId, {
      isEditing: true,
      saveMessage: "",
      saveMessageClass: "",
      saveMessageRole: "status"
    });
  }

  cancelCaseReview(event) {
    const caseId = event.currentTarget.dataset.caseId;
    const caseRecord = this.cases.find((record) => record.Id === caseId);
    if (!caseRecord) {
      return;
    }
    this.updateCase(caseId, {
      diagnosisDraft: caseRecord.diagnosis || "",
      recommendationDraft: caseRecord.recommendation || "",
      caseStatusDraft: caseRecord.caseStatus,
      appointmentRequiredDraft: Boolean(caseRecord.appointmentRequired),
      followUpDateDraft: caseRecord.followUpDate || "",
      isEditing: false,
      saveMessage: "",
      saveMessageClass: "",
      saveMessageRole: "status"
    });
  }

  async saveCaseReview(event) {
    const caseId = event.currentTarget.dataset.caseId;
    const caseRecord = this.cases.find((record) => record.Id === caseId);
    if (!caseRecord) {
      return;
    }
    this.updateCase(caseId, {
      isSaving: true,
      saveMessage: "",
      saveMessageClass: ""
    });

    try {
      const lastModifiedDate = await saveCaseReviewAction({
        healthCaseId: caseId,
        diagnosis: caseRecord.diagnosisDraft,
        recommendation: caseRecord.recommendationDraft,
        caseStatus: caseRecord.caseStatusDraft,
        appointmentRequired: caseRecord.appointmentRequiredDraft,
        followUpDate: caseRecord.followUpDateDraft || null,
        expectedLastModifiedDate: caseRecord.lastModifiedDate
      });
      this.updateCase(caseId, {
        diagnosis: caseRecord.diagnosisDraft,
        recommendation: caseRecord.recommendationDraft,
        caseStatus: caseRecord.caseStatusDraft,
        statusClass: getCaseStatusClass(caseRecord.caseStatusDraft),
        appointmentRequired: caseRecord.appointmentRequiredDraft,
        followUpDate: caseRecord.followUpDateDraft || null,
        lastModifiedDate,
        diagnosisLabel: caseRecord.diagnosisDraft || "No diagnosis recorded",
        recommendationLabel:
          caseRecord.recommendationDraft || "No recommendation recorded",
        appointmentRequiredLabel: caseRecord.appointmentRequiredDraft
          ? "Required"
          : "Not required",
        followUpDateLabel: formatDate(caseRecord.followUpDateDraft),
        hasSavedReview: true,
        isEditing: false,
        isSaving: false,
        saveMessage: "Case review saved.",
        saveMessageClass: "save-success",
        saveMessageRole: "status"
      });
    } catch (error) {
      this.updateCase(caseId, {
        isSaving: false,
        saveMessage: getErrorMessage(error),
        saveMessageClass: "save-error",
        saveMessageRole: "alert"
      });
    }
  }

  updateCase(caseId, changes) {
    this.cases = this.cases.map((caseRecord) => {
      if (caseRecord.Id !== caseId) {
        return caseRecord;
      }
      return { ...caseRecord, ...changes };
    });
  }
}
