public with sharing class HealthConnectPatientDashboardController {
  public class HealthCaseView {
    @AuraEnabled
    public Id Id { get; set; }
    @AuraEnabled
    public String Name { get; set; }
    @AuraEnabled
    public Datetime CreatedDate { get; set; }
    @AuraEnabled
    public String caseStatus { get; set; }
    @AuraEnabled
    public String symptoms { get; set; }
    @AuraEnabled
    public Decimal symptomDurationDays { get; set; }
    @AuraEnabled
    public String diagnosis { get; set; }
    @AuraEnabled
    public String doctorRecommendation { get; set; }
    @AuraEnabled
    public Date followUpDate { get; set; }
    @AuraEnabled
    public Boolean hasAssignedDoctor { get; set; }
    @AuraEnabled
    public String assignedDoctorName { get; set; }

    public HealthCaseView(Health_Case__c record) {
      Id = record.Id;
      Name = record.Name;
      CreatedDate = record.CreatedDate;
      caseStatus = record.Case_Status__c;
      symptoms = record.Symptoms__c;
      symptomDurationDays = record.Symptom_Duration_Days__c;
      diagnosis = record.Diagnosis__c;
      doctorRecommendation = record.Doctor_Recommendation__c;
      followUpDate = record.Follow_up_Date__c;
      hasAssignedDoctor = record.Assigned_Doctor__c != null;
      assignedDoctorName = hasAssignedDoctor
        ? record.Assigned_Doctor__r.Name
        : null;
    }
  }

  public class AppointmentView {
    @AuraEnabled
    public Id Id { get; set; }
    @AuraEnabled
    public String Name { get; set; }
    @AuraEnabled
    public Date appointmentDate { get; set; }
    @AuraEnabled
    public String appointmentTime { get; set; }
    @AuraEnabled
    public String appointmentStatus { get; set; }
    @AuraEnabled
    public Boolean hasAssignedDoctor { get; set; }
    @AuraEnabled
    public String assignedDoctorName { get; set; }
    @AuraEnabled
    public String relatedCaseName { get; set; }
    @AuraEnabled
    public String doctorRecommendation { get; set; }

    public AppointmentView(
      Appointment__c record,
      Map<Id, Health_Case__c> authorizedCases
    ) {
      Id = record.Id;
      Name = record.Name;
      appointmentDate = record.Appointment_Date__c;
      appointmentTime = record.Appointment_Time__c;
      appointmentStatus = record.Appointment_Status__c;
      hasAssignedDoctor = record.Assigned_Doctor__c != null;
      assignedDoctorName = hasAssignedDoctor
        ? record.Assigned_Doctor__r.Name
        : null;
      Health_Case__c authorizedCase = record.Health_Case__c == null
        ? null
        : authorizedCases.get(record.Health_Case__c);
      relatedCaseName = authorizedCase == null ? null : authorizedCase.Name;
      doctorRecommendation = authorizedCase == null
        ? null
        : authorizedCase.Doctor_Recommendation__c;
    }
  }

  public class DashboardData {
    @AuraEnabled
    public Patient__c patient { get; set; }
    @AuraEnabled
    public List<HealthCaseView> healthCases { get; set; }
    @AuraEnabled
    public List<Immunization__c> immunizations { get; set; }
    @AuraEnabled
    public List<Care_Reminder__c> reminders { get; set; }
    @AuraEnabled
    public List<AppointmentView> upcomingAppointments { get; set; }
    @AuraEnabled
    public List<AppointmentView> missedAppointments { get; set; }
    @AuraEnabled
    public List<AppointmentView> cancelledAppointments { get; set; }
    @AuraEnabled
    public List<AppointmentView> pastAppointments { get; set; }
    @AuraEnabled
    public List<AppointmentView> undatedAppointments { get; set; }
    @AuraEnabled
    public Integer healthCaseCount { get; set; }
    @AuraEnabled
    public Integer activeCaseCount { get; set; }
    @AuraEnabled
    public Integer closedCaseCount { get; set; }
    @AuraEnabled
    public Integer pendingFollowUpCount { get; set; }
    @AuraEnabled
    public Integer appointmentCount { get; set; }
    @AuraEnabled
    public Integer upcomingAppointmentCount { get; set; }
    @AuraEnabled
    public Integer missedVisitCount { get; set; }
    @AuraEnabled
    public Integer pendingReminderCount { get; set; }
    @AuraEnabled
    public Integer immunizationCount { get; set; }
    @AuraEnabled
    public Integer upcomingImmunizationCount { get; set; }
    @AuraEnabled
    public Boolean patientSetupPending { get; set; }
  }

  @AuraEnabled(cacheable=true)
  public static DashboardData getDashboard() {
    User portalUser = [
      SELECT ContactId
      FROM User
      WHERE Id = :UserInfo.getUserId()
      LIMIT 1
    ];
    return getDashboardForContact(portalUser.ContactId);
  }

  @AuraEnabled
  public static void ensurePatientForCurrentUser() {
    Id currentUserId = UserInfo.getUserId();
    try {
      User portalUser = [
        SELECT Id, ContactId, Email, FirstName, LastName, UserType
        FROM User
        WHERE Id = :currentUserId
        LIMIT 1
      ];
      if (portalUser.UserType == 'Guest') {
        throw new AuraHandledException(
          'Sign in to the patient portal before setting up your patient profile.'
        );
      }
      if (portalUser.ContactId == null) {
        throw new AuraHandledException(
          'Your portal account is not linked to a patient contact.'
        );
      }

      Contact portalContact = [
        SELECT Id, AccountId, Email, FirstName, LastName
        FROM Contact
        WHERE Id = :portalUser.ContactId
        LIMIT 1
      ];
      Id registrationAccountId = getPatientRegistrationAccountId();
      ensurePatientForCurrentUser(
        portalUser,
        portalContact,
        registrationAccountId
      );
    } catch (Exception provisioningError) {
      System.debug(
        LoggingLevel.ERROR,
        'Patient first-login provisioning failed for User ' +
          currentUserId +
          ': ' +
          provisioningError.getMessage() +
          '\n' +
          provisioningError.getStackTraceString()
      );
      throw new AuraHandledException(
        'We could not prepare your patient profile. Please try again. If this continues, contact your community health worker.'
      );
    }
  }

  @TestVisible
  private static Id ensurePatientForCurrentUser(
    User portalUser,
    Contact portalContact,
    Id registrationAccountId
  ) {
    if (
      portalUser == null ||
      portalUser.Id != UserInfo.getUserId() ||
      portalUser.ContactId == null
    ) {
      throw new AuraHandledException(
        'The signed-in portal account is not linked to a patient contact.'
      );
    }
    if (
      portalContact == null ||
      portalContact.Id != portalUser.ContactId ||
      registrationAccountId == null ||
      portalContact.AccountId != registrationAccountId
    ) {
      throw new AuraHandledException(
        'The signed-in contact does not belong to the configured patient registration account.'
      );
    }

    List<Account> lockedAccounts = [
      SELECT Id
      FROM Account
      WHERE Id = :registrationAccountId
      FOR UPDATE
    ];
    if (lockedAccounts.isEmpty()) {
      throw new AuraHandledException(
        'The configured patient registration account could not be verified.'
      );
    }

    List<Patient__c> existingPatients = [
      SELECT Id
      FROM Patient__c
      WHERE Portal_Contact__c = :portalContact.Id
      LIMIT 2
    ];
    if (existingPatients.size() > 1) {
      throw new AuraHandledException(
        'Multiple patient records are linked to your portal contact. Please contact your community health worker.'
      );
    }
    if (!existingPatients.isEmpty()) {
      return existingPatients[0].Id;
    }

    String patientName = String.isBlank(portalContact.FirstName)
      ? portalContact.LastName
      : portalContact.FirstName + ' ' + portalContact.LastName;
    String patientEmail = String.isBlank(portalUser.Email)
      ? portalContact.Email
      : portalUser.Email;
    Patient__c patient = new Patient__c(
      Name = patientName,
      Email__c = String.isBlank(patientEmail)
        ? null
        : patientEmail.trim().toLowerCase(),
      Patient_Status__c = 'Active',
      Portal_Contact__c = portalContact.Id
    );
    Database.SaveResult insertResult = Database.insert(
      patient,
      true,
      AccessLevel.SYSTEM_MODE
    );
    if (!insertResult.isSuccess()) {
      throw new AuraHandledException(
        'The patient profile could not be created.'
      );
    }
    return insertResult.getId();
  }

  private static Id getPatientRegistrationAccountId() {
    List<Network> patientNetworks = [
      SELECT Id
      FROM Network
      WHERE Name = 'HealthConnect Patient Portal'
      LIMIT 2
    ];
    if (patientNetworks.size() != 1) {
      throw new AuraHandledException(
        'The patient portal registration configuration is missing or ambiguous.'
      );
    }

    Set<Id> accountIds = new Set<Id>();
    for (NetworkSelfRegistration registration : [
      SELECT AccountId
      FROM NetworkSelfRegistration
      WHERE NetworkId = :patientNetworks[0].Id AND AccountId != NULL
    ]) {
      accountIds.add(registration.AccountId);
    }
    if (accountIds.size() != 1) {
      throw new AuraHandledException(
        'The patient portal registration account is missing or ambiguous.'
      );
    }
    return new List<Id>(accountIds)[0];
  }

  @AuraEnabled
  public static Patient__c updatePatientProfile(
    String patientName,
    Date dateOfBirth,
    String phoneNumber,
    String bloodGroup,
    String gender,
    String address,
    String state,
    String district,
    String village
  ) {
    User portalUser = [
      SELECT ContactId
      FROM User
      WHERE Id = :UserInfo.getUserId()
      LIMIT 1
    ];
    return updatePatientProfileForContact(
      portalUser.ContactId,
      patientName,
      dateOfBirth,
      phoneNumber,
      bloodGroup,
      gender,
      address,
      state,
      district,
      village
    );
  }

  @TestVisible
  private static Patient__c updatePatientProfileForContact(
    Id contactId,
    String patientName,
    Date dateOfBirth,
    String phoneNumber,
    String bloodGroup,
    String gender,
    String address,
    String state,
    String district,
    String village
  ) {
    if (contactId == null) {
      throw new AuraHandledException(
        'Your portal user is not linked to a patient contact.'
      );
    }

    List<Patient__c> patients = [
      SELECT Id
      FROM Patient__c
      WHERE Portal_Contact__c = :contactId
      WITH USER_MODE
      LIMIT 2
    ];
    if (patients.isEmpty()) {
      throw new AuraHandledException(
        'No patient profile is linked to your portal account.'
      );
    }
    if (patients.size() > 1) {
      throw new AuraHandledException(
        'Your portal contact is linked to multiple patient records. Please contact support.'
      );
    }

    Patient__c patientToUpdate = new Patient__c(
      Id = patients[0].Id,
      Name = patientName,
      Date_of_Birth__c = dateOfBirth,
      Phone_Number__c = phoneNumber,
      Blood_Group__c = bloodGroup,
      Gender__c = gender,
      Address__c = address,
      State__c = state,
      District__c = district,
      Village__c = village
    );
    try {
      Database.update(patientToUpdate, AccessLevel.USER_MODE);
    } catch (DmlException updateError) {
      throw new AuraHandledException(
        'We could not save your profile. Check your entries and try again.'
      );
    }

    return [
      SELECT
        Id,
        Name,
        Date_of_Birth__c,
        Blood_Group__c,
        Patient_Status__c,
        Phone_Number__c,
        Gender__c,
        Address__c,
        State__c,
        District__c,
        Village__c
      FROM Patient__c
      WHERE Id = :patients[0].Id
      WITH USER_MODE
      LIMIT 1
    ];
  }

  @TestVisible
  private static DashboardData getDashboardForContact(Id contactId) {
    if (contactId == null) {
      throw new AuraHandledException(
        'Your portal user is not linked to a patient contact.'
      );
    }

    List<Patient__c> patients = [
      SELECT
        Id,
        Name,
        Date_of_Birth__c,
        Blood_Group__c,
        Patient_Status__c,
        Phone_Number__c,
        Gender__c,
        Address__c,
        State__c,
        District__c,
        Village__c
      FROM Patient__c
      WHERE Portal_Contact__c = :contactId
      WITH USER_MODE
      LIMIT 2
    ];
    if (patients.isEmpty()) {
      DashboardData pendingDashboard = new DashboardData();
      pendingDashboard.patientSetupPending = true;
      pendingDashboard.healthCases = new List<HealthCaseView>();
      pendingDashboard.immunizations = new List<Immunization__c>();
      pendingDashboard.reminders = new List<Care_Reminder__c>();
      pendingDashboard.upcomingAppointments = new List<AppointmentView>();
      pendingDashboard.missedAppointments = new List<AppointmentView>();
      pendingDashboard.cancelledAppointments = new List<AppointmentView>();
      pendingDashboard.pastAppointments = new List<AppointmentView>();
      pendingDashboard.undatedAppointments = new List<AppointmentView>();
      pendingDashboard.healthCaseCount = 0;
      pendingDashboard.activeCaseCount = 0;
      pendingDashboard.closedCaseCount = 0;
      pendingDashboard.pendingFollowUpCount = 0;
      pendingDashboard.appointmentCount = 0;
      pendingDashboard.upcomingAppointmentCount = 0;
      pendingDashboard.missedVisitCount = 0;
      pendingDashboard.pendingReminderCount = 0;
      pendingDashboard.immunizationCount = 0;
      pendingDashboard.upcomingImmunizationCount = 0;
      return pendingDashboard;
    }
    if (patients.size() > 1) {
      throw new AuraHandledException(
        'Your portal contact is linked to multiple patient records. Please contact support.'
      );
    }

    Patient__c patient = patients[0];
    DashboardData result = new DashboardData();
    result.patient = patient;
    result.healthCaseCount = countPatientRecords(
      'Health_Case__c',
      patient.Id,
      ''
    );
    result.activeCaseCount = countPatientRecords(
      'Health_Case__c',
      patient.Id,
      ' AND (Case_Status__c = null OR Case_Status__c != \'Closed\')'
    );
    result.closedCaseCount = countPatientRecords(
      'Health_Case__c',
      patient.Id,
      ' AND Case_Status__c = \'Closed\''
    );
    result.pendingFollowUpCount = countPatientRecords(
      'Health_Case__c',
      patient.Id,
      ' AND Follow_up_Date__c != null AND (Case_Status__c = null OR Case_Status__c != \'Closed\')'
    );
    result.appointmentCount = countPatientRecords(
      'Appointment__c',
      patient.Id,
      ''
    );
    result.upcomingAppointmentCount = countPatientRecords(
      'Appointment__c',
      patient.Id,
      ' AND Appointment_Date__c >= TODAY AND Appointment_Status__c IN (\'Scheduled\', \'Rescheduled\')'
    );
    result.missedVisitCount = countPatientRecords(
      'Appointment__c',
      patient.Id,
      ' AND Appointment_Date__c < TODAY AND Appointment_Status__c IN (\'Scheduled\', \'Rescheduled\')'
    );
    result.pendingReminderCount = countPatientRecords(
      'Care_Reminder__c',
      patient.Id,
      ' AND Reminder_Status__c = \'Pending\''
    );
    result.immunizationCount = countPatientRecords(
      'Immunization__c',
      patient.Id,
      ''
    );
    result.upcomingImmunizationCount = countPatientRecords(
      'Immunization__c',
      patient.Id,
      ' AND Next_Due_Date__c >= TODAY'
    );
    List<Health_Case__c> patientCases = [
      SELECT
        Id,
        Name,
        CreatedDate,
        Case_Status__c,
        Assigned_Doctor__c,
        Assigned_Doctor__r.Name,
        Symptoms__c,
        Symptom_Duration_Days__c,
        Diagnosis__c,
        Doctor_Recommendation__c,
        Follow_up_Date__c
      FROM Health_Case__c
      WHERE Patient__c = :patient.Id
      WITH USER_MODE
      ORDER BY CreatedDate DESC
      LIMIT 50
    ];
    result.healthCases = new List<HealthCaseView>();
    Set<Id> relatedCaseIds = new Set<Id>();
    for (Health_Case__c patientCase : patientCases) {
      result.healthCases.add(new HealthCaseView(patientCase));
    }
    result.immunizations = [
      SELECT
        Id,
        Name,
        Vaccine_Name__c,
        Dose__c,
        Date_Administered__c,
        Next_Due_Date__c
      FROM Immunization__c
      WHERE Patient__c = :patient.Id
      WITH USER_MODE
      ORDER BY Date_Administered__c DESC
      LIMIT 50
    ];
    result.reminders = [
      SELECT
        Id,
        Name,
        Reminder_Type__c,
        Reminder_Status__c,
        Due_Date__c,
        Reminder_Notes__c
      FROM Care_Reminder__c
      WHERE
        Patient__c = :patient.Id
        AND Reminder_Status__c IN ('Pending', 'Sent')
      WITH USER_MODE
      ORDER BY Due_Date__c ASC
      LIMIT 50
    ];
    List<Appointment__c> upcomingAppointments = [
      SELECT
        Id,
        Name,
        Appointment_Date__c,
        Appointment_Time__c,
        Appointment_Status__c,
        Assigned_Doctor__c,
        Assigned_Doctor__r.Name,
        Health_Case__c
      FROM Appointment__c
      WHERE
        Patient__c = :patient.Id
        AND Appointment_Date__c >= TODAY
        AND Appointment_Status__c IN ('Scheduled', 'Rescheduled')
      WITH USER_MODE
      ORDER BY Appointment_Date__c ASC
      LIMIT 50
    ];
    List<Appointment__c> missedAppointments = [
      SELECT
        Id,
        Name,
        Appointment_Date__c,
        Appointment_Time__c,
        Appointment_Status__c,
        Assigned_Doctor__c,
        Assigned_Doctor__r.Name,
        Health_Case__c
      FROM Appointment__c
      WHERE
        Patient__c = :patient.Id
        AND Appointment_Date__c < TODAY
        AND Appointment_Status__c IN ('Scheduled', 'Rescheduled')
      WITH USER_MODE
      ORDER BY Appointment_Date__c DESC
      LIMIT 50
    ];
    Date appointmentHistoryStartDate = Date.today().addMonths(-3);
    List<Appointment__c> pastAppointments = [
      SELECT
        Id,
        Name,
        Appointment_Date__c,
        Appointment_Time__c,
        Appointment_Status__c,
        Assigned_Doctor__c,
        Assigned_Doctor__r.Name,
        Health_Case__c
      FROM Appointment__c
      WHERE
        Patient__c = :patient.Id
        AND Appointment_Date__c >= :appointmentHistoryStartDate
        AND (Appointment_Date__c < TODAY
        OR Appointment_Status__c = 'Completed')
        AND Appointment_Status__c NOT IN ('Scheduled', 'Rescheduled')
      WITH USER_MODE
      ORDER BY Appointment_Date__c DESC
      LIMIT 200
    ];
    List<Appointment__c> cancelledAppointments = [
      SELECT
        Id,
        Name,
        Appointment_Date__c,
        Appointment_Time__c,
        Appointment_Status__c,
        Assigned_Doctor__c,
        Assigned_Doctor__r.Name,
        Health_Case__c
      FROM Appointment__c
      WHERE
        Patient__c = :patient.Id
        AND Appointment_Date__c >= TODAY
        AND Appointment_Status__c = 'Cancelled'
      WITH USER_MODE
      ORDER BY Appointment_Date__c ASC
      LIMIT 50
    ];
    List<Appointment__c> undatedAppointments = [
      SELECT
        Id,
        Name,
        Appointment_Time__c,
        Appointment_Status__c,
        Assigned_Doctor__c,
        Assigned_Doctor__r.Name,
        Health_Case__c
      FROM Appointment__c
      WHERE Patient__c = :patient.Id AND Appointment_Date__c = NULL
      WITH USER_MODE
      ORDER BY CreatedDate DESC
      LIMIT 50
    ];
    for (Appointment__c appointment : upcomingAppointments) {
      if (appointment.Health_Case__c != null) {
        relatedCaseIds.add(appointment.Health_Case__c);
      }
    }
    for (Appointment__c appointment : pastAppointments) {
      if (appointment.Health_Case__c != null) {
        relatedCaseIds.add(appointment.Health_Case__c);
      }
    }
    for (Appointment__c appointment : missedAppointments) {
      if (appointment.Health_Case__c != null) {
        relatedCaseIds.add(appointment.Health_Case__c);
      }
    }
    for (Appointment__c appointment : cancelledAppointments) {
      if (appointment.Health_Case__c != null) {
        relatedCaseIds.add(appointment.Health_Case__c);
      }
    }
    for (Appointment__c appointment : undatedAppointments) {
      if (appointment.Health_Case__c != null) {
        relatedCaseIds.add(appointment.Health_Case__c);
      }
    }
    Map<Id, Health_Case__c> authorizedCases = new Map<Id, Health_Case__c>();
    if (!relatedCaseIds.isEmpty()) {
      for (Health_Case__c relatedCase : [
        SELECT Id, Name, Doctor_Recommendation__c
        FROM Health_Case__c
        WHERE Patient__c = :patient.Id AND Id IN :relatedCaseIds
        WITH USER_MODE
      ]) {
        authorizedCases.put(relatedCase.Id, relatedCase);
      }
    }
    result.upcomingAppointments = toAppointmentViews(
      upcomingAppointments,
      authorizedCases
    );
    result.missedAppointments = toAppointmentViews(
      missedAppointments,
      authorizedCases
    );
    result.cancelledAppointments = toAppointmentViews(
      cancelledAppointments,
      authorizedCases
    );
    result.pastAppointments = toAppointmentViews(
      pastAppointments,
      authorizedCases
    );
    result.undatedAppointments = toAppointmentViews(
      undatedAppointments,
      authorizedCases
    );
    return result;
  }

  private static List<AppointmentView> toAppointmentViews(
    List<Appointment__c> appointments,
    Map<Id, Health_Case__c> authorizedCases
  ) {
    List<AppointmentView> results = new List<AppointmentView>();
    for (Appointment__c appointment : appointments) {
      results.add(new AppointmentView(appointment, authorizedCases));
    }
    return results;
  }

  private static Integer countPatientRecords(
    String objectApiName,
    Id patientId,
    String additionalFilter
  ) {
    String query =
      'SELECT COUNT() FROM ' +
      objectApiName +
      ' WHERE Patient__c = :patientId' +
      additionalFilter;
    return Database.countQueryWithBinds(
      query,
      new Map<String, Object>{ 'patientId' => patientId },
      AccessLevel.USER_MODE
    );
  }
}
