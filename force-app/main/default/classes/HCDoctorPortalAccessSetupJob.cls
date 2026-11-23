public with sharing class HCDoctorPortalAccessSetupJob implements Queueable {
  private static final String DOCTOR_PROFILE_NAME = 'HealthConnect Doctor Community User';
  private static final String PORTAL_PERMISSION_SET_NAME = 'HealthConnect_Doctor_Portal';

  private final Id doctorId;
  private final Id userId;
  private final Id contactId;

  public HCDoctorPortalAccessSetupJob(Id doctorId, Id userId, Id contactId) {
    this.doctorId = doctorId;
    this.userId = userId;
    this.contactId = contactId;
  }

  public void execute(QueueableContext context) {
    System.attachFinalizer(
      new HCDoctorPortalProvisioningFinalizer(doctorId, userId, contactId)
    );

    Doctor__c doctor = [
      SELECT Id, Email__c, Contact__c, User__c
      FROM Doctor__c
      WHERE Id = :doctorId
      LIMIT 1
    ];
    User portalUser = [
      SELECT Id, ContactId, Email, ProfileId, IsActive
      FROM User
      WHERE Id = :userId
      LIMIT 1
    ];
    Profile doctorProfile = [
      SELECT Id
      FROM Profile
      WHERE Name = :DOCTOR_PROFILE_NAME
      LIMIT 1
    ];
    if (
      doctor.User__c != portalUser.Id ||
      doctor.Contact__c != contactId ||
      portalUser.ContactId != contactId ||
      portalUser.ProfileId != doctorProfile.Id ||
      portalUser.Email.trim().toLowerCase() !=
      doctor.Email__c.trim().toLowerCase()
    ) {
      throw new AuraHandledException(
        'The queued portal identity no longer matches the Doctor record.'
      );
    }

    List<PermissionSet> portalPermissionSets = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = :PORTAL_PERMISSION_SET_NAME
      LIMIT 1
    ];
    if (portalPermissionSets.isEmpty()) {
      throw new AuraHandledException(
        'The doctor portal access permission set is missing.'
      );
    }

    if (
      [
          SELECT Id
          FROM PermissionSetAssignment
          WHERE
            AssigneeId = :portalUser.Id
            AND PermissionSetId = :portalPermissionSets[0].Id
          LIMIT 1
        ]
        .isEmpty()
    ) {
      insert new PermissionSetAssignment(
        AssigneeId = portalUser.Id,
        PermissionSetId = portalPermissionSets[0].Id
      );
    }
    if (!portalUser.IsActive) {
      update new User(Id = portalUser.Id, IsActive = true);
    }
    System.resetPassword(portalUser.Id, true);
  }
}
