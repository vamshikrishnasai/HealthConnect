public with sharing class HCDoctorPortalProvisioningFinalizer implements Finalizer {
  private final Id doctorId;
  private final Id userId;
  private final Id contactId;

  public HCDoctorPortalProvisioningFinalizer(
    Id doctorId,
    Id userId,
    Id contactId
  ) {
    this.doctorId = doctorId;
    this.userId = userId;
    this.contactId = contactId;
  }

  public void execute(FinalizerContext context) {
    Doctor__c doctor = [
      SELECT Id, Contact__c, User__c
      FROM Doctor__c
      WHERE Id = :doctorId
      LIMIT 1
    ];
    if (doctor.Contact__c != contactId || doctor.User__c != userId) {
      return;
    }

    Exception jobError = context.getException();
    if (jobError instanceof System.EmailException) {
      doctor.Provisioning_Status__c = 'Activation Email Failed';
      doctor.Provisioning_Error__c = 'The doctor account exists, but Salesforce could not complete password setup. Retry provisioning to request it again.';
    } else if (jobError != null) {
      doctor.Provisioning_Status__c = 'Failed';
      doctor.Provisioning_Error__c = 'Salesforce could not finish doctor portal access setup. Review the provisioning job, then retry.';
    } else {
      List<PermissionSet> portalPermissionSets = [
        SELECT Id
        FROM PermissionSet
        WHERE Name = 'HealthConnect_Doctor_Portal'
        LIMIT 1
      ];
      Boolean hasPortalPermission =
        !portalPermissionSets.isEmpty() &&
        ![
            SELECT Id
            FROM PermissionSetAssignment
            WHERE
              AssigneeId = :userId
              AND PermissionSetId = :portalPermissionSets[0].Id
            LIMIT 1
          ]
          .isEmpty();
      User portalUser = [
        SELECT Id, IsActive
        FROM User
        WHERE Id = :userId
        LIMIT 1
      ];

      if (portalUser.IsActive && hasPortalPermission) {
        doctor.Provisioning_Status__c = 'Provisioned';
        doctor.Provisioning_Error__c = null;
      } else {
        doctor.Provisioning_Status__c = 'Failed';
        doctor.Provisioning_Error__c = 'Salesforce could not finish doctor portal access setup. Review the provisioning job, then retry.';
      }
    }
    update doctor;
  }
}
