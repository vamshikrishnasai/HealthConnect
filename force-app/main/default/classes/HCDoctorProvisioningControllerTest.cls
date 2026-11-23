@IsTest
private class HCDoctorProvisioningControllerTest {
  @IsTest
  static void rejectsProvisioningWithoutAdministratorPermission() {
    Boolean accessGranted;
    Boolean provisioningRejected = false;
    System.runAs(createUserWithoutProvisioningPermission()) {
      accessGranted = HCDoctorProvisioningController.canProvisionDoctorPortalAccounts();
      try {
        HCDoctorProvisioningController.provisionDoctorPortalAccount(null);
      } catch (AuraHandledException expected) {
        provisioningRejected = true;
      }
    }

    System.assertEquals(false, accessGranted);
    System.assert(
      provisioningRejected,
      'Provisioning must be rejected without the administrator permission.'
    );
  }

  @IsTest
  static void duplicateDoctorEmailSetsFailureStatusWithoutCreatingAnAccount() {
    User provisioningAdmin = createUserWithProvisioningPermission();
    Id doctorId;

    System.runAs(provisioningAdmin) {
      Doctor__c existingDoctor = new Doctor__c(
        Name = 'Existing Doctor',
        Email__c = 'duplicate-doctor@example.test'
      );
      Doctor__c duplicateDoctor = new Doctor__c(
        Name = 'Duplicate Doctor',
        Email__c = 'duplicate-doctor@example.test'
      );
      insert new List<Doctor__c>{ existingDoctor, duplicateDoctor };
      doctorId = duplicateDoctor.Id;

      Boolean duplicateRejected = false;
      try {
        HCDoctorProvisioningController.provisionDoctorPortalAccount(doctorId);
      } catch (AuraHandledException expected) {
        duplicateRejected = true;
      }
      System.assert(
        duplicateRejected,
        'A duplicate Doctor email must be rejected before provisioning.'
      );

      Doctor__c updatedDoctor = [
        SELECT Provisioning_Status__c, Provisioning_Error__c
        FROM Doctor__c
        WHERE Id = :doctorId
      ];
      System.assertEquals('Failed', updatedDoctor.Provisioning_Status__c);
      System.assert(
        updatedDoctor.Provisioning_Error__c.contains('Another Doctor'),
        'The failure state should explain the duplicate without exposing sensitive data.'
      );
    }
  }

  @IsTest
  static void rejectsExistingContactWithoutLinkingAnIdentity() {
    User provisioningAdmin = createUserWithProvisioningPermission();
    String email = uniqueEmail('contact-duplicate');
    Id doctorId;
    Id contactId;

    System.runAs(provisioningAdmin) {
      Account doctorAccount = createDoctorAccount();
      Contact existingContact = new Contact(
        LastName = 'Existing Doctor',
        Email = email,
        AccountId = doctorAccount.Id
      );
      insert existingContact;
      contactId = existingContact.Id;

      Doctor__c doctor = new Doctor__c(
        Name = 'Existing Doctor',
        Email__c = email
      );
      insert doctor;
      doctorId = doctor.Id;

      Boolean duplicateRejected = false;
      try {
        HCDoctorProvisioningController.provisionDoctorPortalAccount(doctorId);
      } catch (AuraHandledException expected) {
        duplicateRejected = true;
      }
      System.assert(
        duplicateRejected,
        'An existing Contact must not be linked implicitly.'
      );
    }

    System.runAs(provisioningAdmin) {
      Doctor__c failedDoctor = [
        SELECT
          Email__c,
          Contact__c,
          User__c,
          Provisioning_Status__c,
          Provisioning_Error__c
        FROM Doctor__c
        WHERE Id = :doctorId
      ];
      System.assertEquals(null, failedDoctor.Contact__c);
      System.assertEquals(null, failedDoctor.User__c);
      System.assertEquals('Failed', failedDoctor.Provisioning_Status__c);
      System.assert(
        failedDoctor.Provisioning_Error__c.contains(
          'Contact already uses this email'
        ),
        'The failure should identify the duplicate Contact without exposing sensitive data.'
      );
      System.assertEquals(
        1,
        [SELECT COUNT() FROM Contact WHERE Id = :contactId]
      );
      System.assertEquals(
        0,
        [SELECT COUNT() FROM User WHERE Email = :failedDoctor.Email__c]
      );
    }
  }

  @IsTest
  static void rejectsLinkedContactWithoutPortalUser() {
    User provisioningAdmin = createUserWithProvisioningPermission();
    Id doctorId;
    System.runAs(provisioningAdmin) {
      Account doctorAccount = createDoctorAccount();
      Contact contact = new Contact(
        LastName = 'Linked Doctor',
        Email = uniqueEmail('linked-contact'),
        AccountId = doctorAccount.Id
      );
      insert contact;
      Doctor__c doctor = new Doctor__c(
        Name = 'Linked Doctor',
        Email__c = uniqueEmail('linked-doctor'),
        Contact__c = contact.Id
      );
      insert doctor;
      doctorId = doctor.Id;

      Boolean rejected = false;
      try {
        HCDoctorProvisioningController.provisionDoctorPortalAccount(doctorId);
      } catch (AuraHandledException expected) {
        rejected = true;
      }
      System.assert(
        rejected,
        'A linked Contact without a User requires manual identity verification.'
      );
    }

    System.runAs(provisioningAdmin) {
      Doctor__c failedDoctor = [
        SELECT Provisioning_Status__c, Provisioning_Error__c
        FROM Doctor__c
        WHERE Id = :doctorId
      ];
      System.assertEquals('Failed', failedDoctor.Provisioning_Status__c);
      System.assert(
        failedDoctor.Provisioning_Error__c.contains(
          'Contact is already linked'
        ),
        'The failure should explain that identity verification is required.'
      );
    }
  }

  @IsTest
  static void rejectsInvalidEmailAndStoresSafeFailure() {
    User provisioningAdmin = createUserWithProvisioningPermission();
    Id doctorId;
    System.runAs(provisioningAdmin) {
      Doctor__c doctor = new Doctor__c(Name = 'Missing Email Doctor');
      insert doctor;
      doctorId = doctor.Id;

      Boolean rejected = false;
      try {
        HCDoctorProvisioningController.provisionDoctorPortalAccount(doctorId);
      } catch (AuraHandledException expected) {
        rejected = true;
      }
      System.assert(
        rejected,
        'An invalid email must be rejected before creating a Contact or User.'
      );

      Doctor__c failedDoctor = [
        SELECT Provisioning_Status__c, Provisioning_Error__c
        FROM Doctor__c
        WHERE Id = :doctorId
      ];
      System.assertEquals('Failed', failedDoctor.Provisioning_Status__c);
      System.assert(
        failedDoctor.Provisioning_Error__c.contains('valid doctor email'),
        'The failure should state the missing email requirement without disclosing account data.'
      );
    }
  }

  @IsTest
  static void rejectsDisabledProvisioningRecord() {
    User provisioningAdmin = createUserWithProvisioningPermission();
    System.runAs(provisioningAdmin) {
      Doctor__c doctor = new Doctor__c(
        Name = 'Disabled Doctor',
        Email__c = uniqueEmail('disabled'),
        Provisioning_Status__c = 'Disabled'
      );
      insert doctor;

      Boolean rejected = false;
      try {
        HCDoctorProvisioningController.provisionDoctorPortalAccount(doctor.Id);
      } catch (AuraHandledException expected) {
        rejected = true;
      }
      System.assert(
        rejected,
        'Disabled Doctor records must never create portal users.'
      );

      Doctor__c unchangedDoctor = [
        SELECT Contact__c, User__c, Provisioning_Status__c
        FROM Doctor__c
        WHERE Id = :doctor.Id
      ];
      System.assertEquals(null, unchangedDoctor.Contact__c);
      System.assertEquals(null, unchangedDoctor.User__c);
      System.assertEquals('Disabled', unchangedDoctor.Provisioning_Status__c);
    }
  }

  @IsTest
  static void rejectsExistingSalesforceUserWithMatchingEmail() {
    User provisioningAdmin = createUserWithProvisioningPermission();
    User existingUser = createTestUser(false);
    String email = uniqueEmail('existing-user');

    System.runAs(provisioningAdmin) {
      existingUser.Email = email;
      update existingUser;
      Doctor__c doctor = new Doctor__c(
        Name = 'Existing Salesforce User',
        Email__c = email
      );
      insert doctor;

      Boolean rejected = false;
      try {
        HCDoctorProvisioningController.provisionDoctorPortalAccount(doctor.Id);
      } catch (AuraHandledException expected) {
        rejected = true;
      }
      System.assert(
        rejected,
        'A matching Salesforce user must not be linked implicitly.'
      );

      Doctor__c failedDoctor = [
        SELECT
          Contact__c,
          User__c,
          Provisioning_Status__c,
          Provisioning_Error__c
        FROM Doctor__c
        WHERE Id = :doctor.Id
      ];
      System.assertEquals(null, failedDoctor.Contact__c);
      System.assertEquals(null, failedDoctor.User__c);
      System.assertEquals('Failed', failedDoctor.Provisioning_Status__c);
      System.assert(
        failedDoctor.Provisioning_Error__c.contains(
          'Salesforce user already uses this email'
        ),
        'The failure should require administrator verification of the existing identity.'
      );
    }
  }

  @IsTest
  static void provisionsDoctorAndAllowsSafeActivationRetry() {
    User provisioningAdmin = createUserWithProvisioningPermission();
    String email = uniqueEmail('provision-success');
    Id doctorId;
    Id provisionedUserId;

    System.runAs(provisioningAdmin) {
      createDoctorAccount();
      Doctor__c doctor = new Doctor__c(
        Name = 'Jordan Health Doctor',
        Email__c = email
      );
      insert doctor;
      doctorId = doctor.Id;

      Test.startTest();
      HCDoctorProvisioningController.ProvisioningResult firstResult = HCDoctorProvisioningController.provisionDoctorPortalAccount(
        doctorId
      );
      Doctor__c provisionedDoctor = [
        SELECT Email__c, Contact__c, User__c, Provisioning_Status__c
        FROM Doctor__c
        WHERE Id = :doctorId
      ];
      provisionedUserId = provisionedDoctor.User__c;
      System.assertEquals('Pending', provisionedDoctor.Provisioning_Status__c);
      System.assertNotEquals(null, provisionedDoctor.Contact__c);
      System.assertNotEquals(null, provisionedDoctor.User__c);
      System.assertEquals('Pending', firstResult.status);
      System.assert(
        firstResult.message.contains('processing'),
        'The result should explain that activation continues asynchronously.'
      );

      HCDoctorProvisioningController.ProvisioningResult retryResult = HCDoctorProvisioningController.provisionDoctorPortalAccount(
        doctorId
      );
      System.assertEquals('Pending', retryResult.status);
      System.assertEquals(
        1,
        [SELECT COUNT() FROM User WHERE Id = :provisionedUserId],
        'A repeated action while pending must not create another user.'
      );
      Test.stopTest();

      User provisionedUser = [
        SELECT IsActive
        FROM User
        WHERE Id = :provisionedUserId
      ];
      System.assert(
        provisionedUser.IsActive,
        'The setup job should activate the user.'
      );
      Doctor__c completedDoctor = [
        SELECT Provisioning_Status__c
        FROM Doctor__c
        WHERE Id = :doctorId
      ];
      System.assert(
        completedDoctor.Provisioning_Status__c == 'Provisioned' ||
          completedDoctor.Provisioning_Status__c == 'Activation Email Failed',
        'The queueable finalizer should persist the asynchronous outcome.'
      );
      System.assertEquals(
        1,
        [
          SELECT COUNT()
          FROM PermissionSetAssignment
          WHERE
            AssigneeId = :provisionedUserId
            AND PermissionSet.Name = 'HealthConnect_Doctor_Portal'
        ],
        'The user must receive the dedicated doctor portal permission set.'
      );
    }
  }

  private static User createUserWithoutProvisioningPermission() {
    return createTestUser(false);
  }

  private static User createUserWithProvisioningPermission() {
    return createTestUser(true);
  }

  private static User createTestUser(Boolean assignProvisioningPermission) {
    Profile adminProfile = [
      SELECT Id
      FROM Profile
      WHERE Name = 'System Administrator'
      LIMIT 1
    ];
    String username =
      'hc-provisioning-' +
      String.valueOf(DateTime.now().getTime()) +
      '@example.test';
    User testUser = new User(
      Alias = 'hcadmin',
      Email = username,
      EmailEncodingKey = 'UTF-8',
      LastName = 'Provisioning Admin',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = adminProfile.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      Username = username
    );
    List<UserRole> availableRoles = [
      SELECT Id
      FROM UserRole
      LIMIT 1
    ];
    if (!availableRoles.isEmpty()) {
      testUser.UserRoleId = availableRoles[0].Id;
    }
    insert testUser;

    if (assignProvisioningPermission) {
      PermissionSet provisioningPermissionSet = [
        SELECT Id
        FROM PermissionSet
        WHERE Name = 'HealthConnect_Doctor_Provisioning_Admin'
        LIMIT 1
      ];
      insert new PermissionSetAssignment(
        AssigneeId = testUser.Id,
        PermissionSetId = provisioningPermissionSet.Id
      );
    }
    return testUser;
  }

  private static String uniqueEmail(String prefix) {
    return prefix +
      '-' +
      String.valueOf(DateTime.now().getTime()) +
      '@example.test';
  }

  private static Account createDoctorAccount() {
    Account account = new Account(Name = 'HealthConnect Doctor Portal Account');
    insert account;
    return account;
  }
}
