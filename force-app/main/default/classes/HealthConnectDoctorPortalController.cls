public with sharing class HealthConnectDoctorPortalController {
  public class AssignedCaseView {
    @AuraEnabled
    public Id Id { get; set; }
    @AuraEnabled
    public String Name { get; set; }
    @AuraEnabled
    public String patientName { get; set; }
    @AuraEnabled
    public Date patientDateOfBirth { get; set; }
    @AuraEnabled
    public String patientPhoneNumber { get; set; }
    @AuraEnabled
    public Datetime createdDate { get; set; }
    @AuraEnabled
    public String caseStatus { get; set; }
    @AuraEnabled
    public String symptoms { get; set; }
    @AuraEnabled
    public Decimal symptomDurationDays { get; set; }
    @AuraEnabled
    public String diagnosis { get; set; }
    @AuraEnabled
    public String recommendation { get; set; }
    @AuraEnabled
    public Date followUpDate { get; set; }
    @AuraEnabled
    public String casePriority { get; set; }
    @AuraEnabled
    public Boolean appointmentRequired { get; set; }
    @AuraEnabled
    public Datetime lastModifiedDate { get; set; }

    public AssignedCaseView(Health_Case__c healthCase) {
      Id = healthCase.Id;
      Name = healthCase.Name;
      patientName = healthCase.Patient__r.Name;
      patientDateOfBirth = healthCase.Patient__r.Date_of_Birth__c;
      patientPhoneNumber = healthCase.Patient__r.Phone_Number__c;
      createdDate = healthCase.CreatedDate;
      caseStatus = healthCase.Case_Status__c;
      symptoms = healthCase.Symptoms__c;
      symptomDurationDays = healthCase.Symptom_Duration_Days__c;
      diagnosis = healthCase.Diagnosis__c;
      recommendation = healthCase.Doctor_Recommendation__c;
      followUpDate = healthCase.Follow_up_Date__c;
      casePriority = healthCase.Case_Priority__c;
      appointmentRequired = healthCase.Appointment_Required__c;
      lastModifiedDate = healthCase.LastModifiedDate;
    }
  }

  public class AssignedAppointmentView {
    @AuraEnabled
    public Id Id { get; set; }
    @AuraEnabled
    public String Name { get; set; }
    @AuraEnabled
    public String patientName { get; set; }
    @AuraEnabled
    public String caseName { get; set; }
    @AuraEnabled
    public Date appointmentDate { get; set; }
    @AuraEnabled
    public String appointmentTime { get; set; }
    @AuraEnabled
    public String appointmentStatus { get; set; }
    @AuraEnabled
    public String notes { get; set; }

    public AssignedAppointmentView(Appointment__c appointment) {
      Id = appointment.Id;
      Name = appointment.Name;
      patientName = appointment.Patient__r.Name;
      caseName = appointment.Health_Case__r == null
        ? null
        : appointment.Health_Case__r.Name;
      appointmentDate = appointment.Appointment_Date__c;
      appointmentTime = appointment.Appointment_Time__c;
      appointmentStatus = appointment.Appointment_Status__c;
      notes = appointment.Appointment_Notes__c;
    }
  }

  @AuraEnabled(cacheable=true)
  public static Boolean hasDoctorPortalAccess() {
    return FeatureManagement.checkPermission('HealthConnect_Doctor_Portal');
  }

  @AuraEnabled(cacheable=true)
  public static List<AssignedCaseView> getAssignedCases() {
    requireDoctorPortalAccess();

    List<Health_Case__c> assignedCases = [
      SELECT
        Id,
        Name,
        CreatedDate,
        LastModifiedDate,
        Case_Priority__c,
        Case_Status__c,
        Appointment_Required__c,
        Symptoms__c,
        Symptom_Duration_Days__c,
        Diagnosis__c,
        Doctor_Recommendation__c,
        Follow_up_Date__c,
        Patient__r.Name,
        Patient__r.Date_of_Birth__c,
        Patient__r.Phone_Number__c
      FROM Health_Case__c
      WHERE Assigned_Doctor__c = :UserInfo.getUserId()
      WITH USER_MODE
      ORDER BY CreatedDate DESC
    ];

    List<AssignedCaseView> result = new List<AssignedCaseView>();
    for (Health_Case__c healthCase : assignedCases) {
      result.add(new AssignedCaseView(healthCase));
    }
    return result;
  }

  @AuraEnabled(cacheable=true)
  public static List<AssignedAppointmentView> getAssignedAppointments() {
    requireDoctorPortalAccess();
    List<Appointment__c> assignedAppointments = [
      SELECT
        Id,
        Name,
        Patient__r.Name,
        Health_Case__r.Name,
        Appointment_Date__c,
        Appointment_Time__c,
        Appointment_Status__c,
        Appointment_Notes__c
      FROM Appointment__c
      WHERE
        Assigned_Doctor__c = :UserInfo.getUserId()
        AND Appointment_Date__c >= TODAY
        AND Appointment_Status__c IN ('Scheduled', 'Rescheduled')
      WITH USER_MODE
      ORDER BY Appointment_Date__c ASC, Appointment_Time__c ASC
    ];
    List<AssignedAppointmentView> result = new List<AssignedAppointmentView>();
    for (Appointment__c appointment : assignedAppointments) {
      result.add(new AssignedAppointmentView(appointment));
    }
    return result;
  }

  @AuraEnabled
  public static void saveRecommendation(
    Id healthCaseId,
    String recommendation
  ) {
    requireDoctorPortalAccess();
    Health_Case__c currentCase = getEditableAssignedCase(healthCaseId, null);
    saveCaseReview(
      healthCaseId,
      currentCase.Diagnosis__c,
      recommendation,
      currentCase.Case_Status__c,
      currentCase.Appointment_Required__c,
      currentCase.Follow_up_Date__c,
      currentCase.LastModifiedDate
    );
  }

  @AuraEnabled
  public static Datetime saveCaseReview(
    Id healthCaseId,
    String diagnosis,
    String recommendation,
    String caseStatus,
    Boolean appointmentRequired,
    Date followUpDate,
    Datetime expectedLastModifiedDate
  ) {
    requireDoctorPortalAccess();
    if (healthCaseId == null) {
      throw new AuraHandledException(
        'Select an assigned health case before saving.'
      );
    }
    if (diagnosis != null && diagnosis.length() > 255) {
      throw new AuraHandledException(
        'Diagnosis is too long. Shorten it and try again.'
      );
    }
    if (recommendation != null && recommendation.length() > 32768) {
      throw new AuraHandledException(
        'The recommendation is too long. Shorten it and try again.'
      );
    }
    if (
      !Schema.sObjectType.Health_Case__c.isUpdateable() ||
      !Schema.sObjectType.Health_Case__c.fields.Diagnosis__c.isUpdateable() ||
      !Schema.sObjectType.Health_Case__c.fields.Doctor_Recommendation__c.isUpdateable() ||
      !Schema.sObjectType.Health_Case__c.fields.Appointment_Required__c.isUpdateable() ||
      !Schema.sObjectType.Health_Case__c.fields.Follow_up_Date__c.isUpdateable()
    ) {
      throw new AuraHandledException(
        'You do not have permission to update all requested case fields.'
      );
    }

    Health_Case__c currentCase = getEditableAssignedCase(
      healthCaseId,
      expectedLastModifiedDate
    );
    currentCase.Diagnosis__c = diagnosis;
    currentCase.Doctor_Recommendation__c = recommendation;
    currentCase.Case_Status__c = caseStatus;
    currentCase.Appointment_Required__c = appointmentRequired;
    currentCase.Follow_up_Date__c = followUpDate;
    try {
      // Salesforce rejects explicit field permissions for required Case_Status__c.
      Database.update(
        new Health_Case__c(
          Id = currentCase.Id,
          Diagnosis__c = diagnosis,
          Doctor_Recommendation__c = recommendation,
          Case_Status__c = caseStatus,
          Appointment_Required__c = appointmentRequired,
          Follow_up_Date__c = followUpDate
        )
      );
    } catch (DmlException error) {
      String message = error.getNumDml() > 0
        ? error.getDmlMessage(0)
        : 'The case could not be saved. Check the values and try again.';
      throw new AuraHandledException(message);
    }
    return [
      SELECT LastModifiedDate
      FROM Health_Case__c
      WHERE Id = :healthCaseId
      WITH USER_MODE
      LIMIT 1
    ]
    .LastModifiedDate;
  }

  private static Health_Case__c getEditableAssignedCase(
    Id healthCaseId,
    Datetime expectedLastModifiedDate
  ) {
    if (healthCaseId == null) {
      throw new AuraHandledException(
        'Select an assigned health case before saving.'
      );
    }
    List<Health_Case__c> assignedCases = [
      SELECT
        Id,
        Diagnosis__c,
        Doctor_Recommendation__c,
        Case_Status__c,
        Appointment_Required__c,
        Follow_up_Date__c,
        LastModifiedDate
      FROM Health_Case__c
      WHERE Id = :healthCaseId AND Assigned_Doctor__c = :UserInfo.getUserId()
      WITH USER_MODE
      LIMIT 1
    ];
    if (assignedCases.isEmpty()) {
      throw new AuraHandledException(
        'You do not have access to update this health case.'
      );
    }
    Health_Case__c currentCase = assignedCases[0];
    if (
      expectedLastModifiedDate != null &&
      currentCase.LastModifiedDate != expectedLastModifiedDate
    ) {
      throw new AuraHandledException(
        'This case changed after you opened it. Refresh the dashboard before saving.'
      );
    }
    return currentCase;
  }

  private static void requireDoctorPortalAccess() {
    if (!hasDoctorPortalAccess()) {
      throw new AuraHandledException(
        'You do not have access to the doctor portal.'
      );
    }
  }
}
