public without sharing class HealthConnectDoctorProfileController {
  public class DoctorProfileView {
    @AuraEnabled
    public String name { get; set; }
    @AuraEnabled
    public String specialization { get; set; }
    @AuraEnabled
    public String email { get; set; }
    @AuraEnabled
    public String phoneNumber { get; set; }
    @AuraEnabled
    public String healthcareFacility { get; set; }
    @AuraEnabled
    public String district { get; set; }
    @AuraEnabled
    public String availabilityStatus { get; set; }
    @AuraEnabled
    public String profileError { get; set; }

    public DoctorProfileView() {
      name = UserInfo.getName();
    }

    public DoctorProfileView(Doctor__c doctor) {
      name = doctor.Name;
      specialization = doctor.Specialization__c;
      email = doctor.Email__c;
      phoneNumber = doctor.Phone_Number__c;
      healthcareFacility = doctor.Healthcare_Facility__c;
      district = doctor.District__c;
      availabilityStatus = doctor.Availability_Status__c;
    }
  }

  @AuraEnabled
  public static DoctorProfileView getCurrentDoctorProfile() {
    if (!FeatureManagement.checkPermission('HealthConnect_Doctor_Portal')) {
      throw new AuraHandledException(
        'You do not have access to the doctor portal.'
      );
    }
    if (
      !Schema.sObjectType.Doctor__c.isAccessible() ||
      !Schema.sObjectType.Doctor__c.fields.User__c.isAccessible() ||
      !Schema.sObjectType.Doctor__c.fields.Contact__c.isAccessible() ||
      !Schema.sObjectType.Doctor__c.fields.Specialization__c.isAccessible() ||
      !Schema.sObjectType.Doctor__c.fields.Email__c.isAccessible() ||
      !Schema.sObjectType.Doctor__c.fields.Phone_Number__c.isAccessible() ||
      !Schema.sObjectType.Doctor__c.fields.Healthcare_Facility__c.isAccessible() ||
      !Schema.sObjectType.Doctor__c.fields.District__c.isAccessible() ||
      !Schema.sObjectType.Doctor__c.fields.Availability_Status__c.isAccessible()
    ) {
      throw new AuraHandledException(
        'Your profile details are not available with your current portal permissions. Contact your administrator.'
      );
    }

    User currentUser = [
      SELECT ContactId
      FROM User
      WHERE Id = :UserInfo.getUserId()
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    List<Doctor__c> doctorProfiles = [
      SELECT
        Id,
        Name,
        Specialization__c,
        Email__c,
        Phone_Number__c,
        Healthcare_Facility__c,
        District__c,
        Availability_Status__c
      FROM Doctor__c
      WHERE User__c = :currentUser.Id
      WITH SYSTEM_MODE
      LIMIT 2
    ];
    if (doctorProfiles.isEmpty() && currentUser.ContactId != null) {
      doctorProfiles = [
        SELECT
          Id,
          Name,
          Specialization__c,
          Email__c,
          Phone_Number__c,
          Healthcare_Facility__c,
          District__c,
          Availability_Status__c
        FROM Doctor__c
        WHERE Contact__c = :currentUser.ContactId
        WITH SYSTEM_MODE
        LIMIT 2
      ];
    }
    if (doctorProfiles.isEmpty()) {
      DoctorProfileView unavailableProfile = new DoctorProfileView();
      unavailableProfile.profileError = currentUser.ContactId == null
        ? 'This portal login has no Contact association. Ask your HealthConnect administrator to sign in with the external user linked to the Doctor record.'
        : 'No Doctor record matches this portal user or its Contact. Ask your HealthConnect administrator to verify that this login belongs to the linked Doctor account.';
      return unavailableProfile;
    }
    if (doctorProfiles.size() > 1) {
      DoctorProfileView unavailableProfile = new DoctorProfileView();
      unavailableProfile.profileError = 'More than one Doctor record is linked to this portal user or its Contact. Ask your HealthConnect administrator to resolve the links.';
      return unavailableProfile;
    }
    return new DoctorProfileView(doctorProfiles[0]);
  }

  @AuraEnabled
  public static DoctorProfileView saveCurrentDoctorProfile(
    String phoneNumber,
    String specialization,
    String healthcareFacility,
    String district,
    String availabilityStatus
  ) {
    if (!FeatureManagement.checkPermission('HealthConnect_Doctor_Portal')) {
      throw new AuraHandledException(
        'You do not have access to the doctor portal.'
      );
    }
    if (
      !Schema.sObjectType.Doctor__c.isUpdateable() ||
      !Schema.sObjectType.Doctor__c.fields.Phone_Number__c.isUpdateable() ||
      !Schema.sObjectType.Doctor__c.fields.Specialization__c.isUpdateable() ||
      !Schema.sObjectType.Doctor__c.fields.Healthcare_Facility__c.isUpdateable() ||
      !Schema.sObjectType.Doctor__c.fields.District__c.isUpdateable() ||
      !Schema.sObjectType.Doctor__c.fields.Availability_Status__c.isUpdateable()
    ) {
      throw new AuraHandledException(
        'Your profile fields are not editable with the current portal permissions. Contact your administrator.'
      );
    }
    validatePicklistValue(
      Schema.sObjectType.Doctor__c.fields.Specialization__c,
      specialization,
      'specialization'
    );
    validatePicklistValue(
      Schema.sObjectType.Doctor__c.fields.Availability_Status__c,
      availabilityStatus,
      'availability'
    );

    User currentUser = [
      SELECT ContactId
      FROM User
      WHERE Id = :UserInfo.getUserId()
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    List<Doctor__c> doctorProfiles = [
      SELECT
        Id,
        Name,
        Specialization__c,
        Email__c,
        Phone_Number__c,
        Healthcare_Facility__c,
        District__c,
        Availability_Status__c
      FROM Doctor__c
      WHERE User__c = :currentUser.Id
      WITH SYSTEM_MODE
      LIMIT 2
    ];
    if (doctorProfiles.isEmpty() && currentUser.ContactId != null) {
      doctorProfiles = [
        SELECT
          Id,
          Name,
          Specialization__c,
          Email__c,
          Phone_Number__c,
          Healthcare_Facility__c,
          District__c,
          Availability_Status__c
        FROM Doctor__c
        WHERE Contact__c = :currentUser.ContactId
        WITH SYSTEM_MODE
        LIMIT 2
      ];
    }
    if (doctorProfiles.isEmpty()) {
      throw new AuraHandledException(
        'Your Doctor profile is not linked to this portal account.'
      );
    }
    if (doctorProfiles.size() != 1) {
      throw new AuraHandledException(
        'Your portal account is linked to multiple Doctor records. Contact your administrator.'
      );
    }

    Doctor__c doctor = doctorProfiles[0];
    doctor.Phone_Number__c = normalizeOptionalValue(
      phoneNumber,
      Schema.sObjectType.Doctor__c.fields.Phone_Number__c.getLength(),
      'Phone'
    );
    doctor.Specialization__c = specialization;
    doctor.Healthcare_Facility__c = normalizeOptionalValue(
      healthcareFacility,
      Schema.sObjectType.Doctor__c.fields.Healthcare_Facility__c.getLength(),
      'Facility'
    );
    doctor.District__c = normalizeOptionalValue(
      district,
      Schema.sObjectType.Doctor__c.fields.District__c.getLength(),
      'District'
    );
    doctor.Availability_Status__c = availabilityStatus;

    try {
      Database.update(doctor, AccessLevel.SYSTEM_MODE);
    } catch (DmlException error) {
      throw new AuraHandledException(
        'We could not save your profile. Check the values and try again.'
      );
    }
    return new DoctorProfileView(doctor);
  }

  private static void validatePicklistValue(
    Schema.DescribeFieldResult field,
    String value,
    String fieldLabel
  ) {
    if (String.isBlank(value)) {
      return;
    }
    for (Schema.PicklistEntry option : field.getPicklistValues()) {
      if (option.isActive() && option.getValue() == value) {
        return;
      }
    }
    throw new AuraHandledException('Select a valid ' + fieldLabel + ' value.');
  }

  private static String normalizeOptionalValue(
    String value,
    Integer maxLength,
    String fieldLabel
  ) {
    String normalizedValue = String.isBlank(value) ? null : value.trim();
    if (normalizedValue != null && normalizedValue.length() > maxLength) {
      throw new AuraHandledException(
        fieldLabel + ' must be ' + maxLength + ' characters or fewer.'
      );
    }
    return normalizedValue;
  }
}
