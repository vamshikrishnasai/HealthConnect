@IsTest
private class AutocreatedConfigSelfRegTest {
  @IsTest
  static void createsAnEmptyPatientForAContactWithoutAnEmailMatch() {
    Account account = new Account(Name = 'Registration Test Account');
    insert account;
    Contact contact = new Contact(
      FirstName = 'New',
      LastName = 'Patient',
      Email = 'new.patient@example.test',
      AccountId = account.Id
    );
    insert contact;

    Id patientId = AutocreatedConfigSelfReg1792833096140.createPatientForContact(
      contact.Id,
      contact.Email,
      'New Patient'
    );

    Patient__c patient = [
      SELECT Id, Name, Email__c, Patient_Status__c, Portal_Contact__c
      FROM Patient__c
      WHERE Id = :patientId
    ];
    System.assertEquals('New Patient', patient.Name);
    System.assertEquals('new.patient@example.test', patient.Email__c);
    System.assertEquals('Active', patient.Patient_Status__c);
    System.assertEquals(contact.Id, patient.Portal_Contact__c);
  }

  @IsTest
  static void doesNotAttachAContactToAnExistingPatientByEmail() {
    Account account = new Account(Name = 'Existing Patient Test Account');
    insert account;
    Contact existingContact = new Contact(
      LastName = 'Existing',
      Email = 'shared.patient@example.test',
      AccountId = account.Id
    );
    Contact newContact = new Contact(
      LastName = 'Registrant',
      Email = 'shared.patient@example.test',
      AccountId = account.Id
    );
    insert new List<Contact>{ existingContact, newContact };
    Patient__c existingPatient = new Patient__c(
      Name = 'Existing Patient',
      Email__c = 'shared.patient@example.test',
      Portal_Contact__c = existingContact.Id
    );
    insert existingPatient;

    Id patientId = AutocreatedConfigSelfReg1792833096140.createPatientForContact(
      newContact.Id,
      newContact.Email,
      'Registrant'
    );

    System.assertEquals(
      null,
      patientId,
      'Email matching alone must not link a new registrant to an existing clinical record.'
    );
    System.assertEquals(
      1,
      [
        SELECT COUNT()
        FROM Patient__c
        WHERE Email__c = 'shared.patient@example.test'
      ]
    );
    System.assertEquals(
      0,
      [SELECT COUNT() FROM Patient__c WHERE Portal_Contact__c = :newContact.Id]
    );
  }

  @IsTest
  static void provisioningSkipsAUserWithoutAContact() {
    User currentUser = [
      SELECT ContactId
      FROM User
      WHERE Id = :UserInfo.getUserId()
    ];
    System.assertEquals(null, currentUser.ContactId);

    Test.startTest();
    AutocreatedConfigSelfReg1792833096140.provisionPatient(
      UserInfo.getUserId()
    );
    Test.stopTest();
  }

  @IsTest
  static void provisioningUsesTheTriggerUserSnapshotForRegisteredContacts() {
    Account account = new Account(Name = 'Registration Snapshot Test Account');
    insert account;
    Contact contact = new Contact(
      FirstName = 'Snapshot',
      LastName = 'Patient',
      Email = 'snapshot.patient@example.test',
      AccountId = account.Id
    );
    insert contact;

    Test.startTest();
    AutocreatedConfigSelfReg1792833096140.provisionRegisteredPatientUsers(
      new List<Id>{ UserInfo.getUserId() },
      new List<Id>{ contact.Id },
      new List<String>{ contact.Email },
      new List<String>{ contact.FirstName },
      new List<String>{ contact.LastName },
      new List<Id>{ account.Id }
    );
    Test.stopTest();

    Patient__c patient = [
      SELECT Name, Email__c, Portal_Contact__c
      FROM Patient__c
      WHERE Email__c = :contact.Email
    ];
    System.assertEquals('Snapshot Patient', patient.Name);
    System.assertEquals(contact.Email, patient.Email__c);
    System.assertEquals(contact.Id, patient.Portal_Contact__c);
  }

  @IsTest
  static void patientSnapshotProvisioningCreatesOnePatientPerContact() {
    Account account = new Account(Name = 'Idempotent Snapshot Test Account');
    insert account;
    Contact contact = new Contact(
      FirstName = 'Idempotent',
      LastName = 'Patient',
      Email = 'idempotent.patient@example.test',
      AccountId = account.Id
    );
    insert contact;

    Test.startTest();
    for (Integer attempt = 0; attempt < 2; attempt++) {
      AutocreatedConfigSelfReg1792833096140.provisionPatientSnapshots(
        new List<Id>{ UserInfo.getUserId() },
        new List<Id>{ contact.Id },
        new List<Id>{ account.Id },
        new List<String>{ contact.Email },
        new List<String>{ contact.FirstName },
        new List<String>{ contact.LastName },
        new List<Id>{ account.Id }
      );
    }
    Test.stopTest();

    List<Patient__c> patients = [
      SELECT Id, Portal_Contact__c
      FROM Patient__c
      WHERE Portal_Contact__c = :contact.Id
    ];
    System.assertEquals(1, patients.size());
    System.assertEquals(contact.Id, patients[0].Portal_Contact__c);
  }

  @IsTest
  static void patientSnapshotProvisioningRequiresRegistrationAccountMatch() {
    Account account = new Account(Name = 'Snapshot Scope Test Account');
    Account differentAccount = new Account(
      Name = 'Different Registration Scope Test Account'
    );
    insert new List<Account>{ account, differentAccount };
    Contact contact = new Contact(
      LastName = 'Out Of Scope',
      Email = 'out.of.scope@example.test',
      AccountId = account.Id
    );
    insert contact;

    Test.startTest();
    AutocreatedConfigSelfReg1792833096140.provisionPatientSnapshots(
      new List<Id>{ UserInfo.getUserId() },
      new List<Id>{ contact.Id },
      new List<Id>{ account.Id },
      new List<String>{ contact.Email },
      new List<String>{ contact.FirstName },
      new List<String>{ contact.LastName },
      new List<Id>{ differentAccount.Id }
    );
    Test.stopTest();

    System.assertEquals(
      0,
      [SELECT COUNT() FROM Patient__c WHERE Portal_Contact__c = :contact.Id]
    );
  }

  @IsTest
  static void permissionSnapshotEligibilityRequiresPortalUserAndAccount() {
    Account account = new Account(Name = 'Permission Snapshot Test Account');
    insert account;
    Contact contact = new Contact(
      LastName = 'Permission Snapshot Patient',
      AccountId = account.Id
    );
    insert contact;

    System.assertEquals(
      true,
      AutocreatedConfigSelfReg1792833096140.isEligiblePortalUserSnapshot(
        'PowerCustomerSuccess',
        contact.Id,
        account.Id,
        new Set<Id>{ account.Id }
      )
    );
    System.assertEquals(
      false,
      AutocreatedConfigSelfReg1792833096140.isEligiblePortalUserSnapshot(
        'Standard',
        contact.Id,
        account.Id,
        new Set<Id>{ account.Id }
      )
    );
    System.assertEquals(
      false,
      AutocreatedConfigSelfReg1792833096140.isEligiblePortalUserSnapshot(
        'PowerCustomerSuccess',
        contact.Id,
        account.Id,
        new Set<Id>{ UserInfo.getUserId() }
      )
    );
    System.assertEquals(
      false,
      AutocreatedConfigSelfReg1792833096140.isEligiblePortalUserSnapshot(
        'PowerCustomerSuccess',
        null,
        account.Id,
        new Set<Id>{ account.Id }
      )
    );
  }

  @IsTest
  static void registrationTriggerEligibilityUsesRegistrationContextProfile() {
    Account account = new Account(
      Name = 'Registration Profile Eligibility Test Account'
    );
    insert account;
    Contact contact = new Contact(
      LastName = 'Registration Profile Eligibility',
      AccountId = account.Id
    );
    insert contact;

    Id portalProfileId = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Customer Community Plus Login User'
      LIMIT 1
    ]
    .Id;
    User externalSnapshot = new User(
      Id = UserInfo.getUserId(),
      ProfileId = portalProfileId,
      ContactId = contact.Id
    );
    User standardSnapshot = [
      SELECT Id, ProfileId, ContactId, UserType
      FROM User
      WHERE Id = :UserInfo.getUserId()
    ];
    standardSnapshot.ProfileId = portalProfileId;
    standardSnapshot.ContactId = contact.Id;

    System.assertEquals(
      true,
      AutocreatedConfigSelfReg1792833096140.isPatientPortalRegistrationUser(
        externalSnapshot,
        portalProfileId
      )
    );
    System.assertEquals(
      false,
      AutocreatedConfigSelfReg1792833096140.isPatientPortalRegistrationUser(
        standardSnapshot,
        portalProfileId
      )
    );
    System.assertEquals(
      false,
      AutocreatedConfigSelfReg1792833096140.isPatientPortalRegistrationUser(
        externalSnapshot,
        UserInfo.getProfileId()
      )
    );
  }

  @IsTest
  static void asyncProvisioningIgnoresIncompleteSnapshots() {
    Test.startTest();
    AutocreatedConfigSelfReg1792833096140.provisionPatientSnapshots(
      null,
      null,
      null,
      null,
      null,
      null,
      null
    );
    Test.stopTest();

    System.assertEquals(0, [SELECT COUNT() FROM Patient__c]);
  }

  @IsTest
  static void provisioningTriggerHandlerIgnoresEmptyInput() {
    AutocreatedConfigSelfReg1792833096140.enqueueProvisioningForUsers(null);
    AutocreatedConfigSelfReg1792833096140.enqueueProvisioningForUsers(
      new List<User>()
    );
    System.assertEquals(
      0,
      AutocreatedConfigSelfReg1792833096140.getRegisteredPatientUsers(
          null,
          new Set<Id>()
        )
        .size()
    );

    System.assertEquals(0, [SELECT COUNT() FROM Patient__c]);
  }

  @IsTest
  static void queuesProvisioningWithoutPublishingAPlatformEvent() {
    Account account = new Account(Name = 'Queueable Provisioning Test Account');
    insert account;
    Contact contact = new Contact(
      LastName = 'Queueable Patient',
      AccountId = account.Id
    );
    insert contact;

    AutocreatedConfigSelfReg1792833096140.enqueueProvisioning(
      new List<Id>{ UserInfo.getUserId() },
      account.Id
    );
    System.assertEquals(1, Limits.getQueueableJobs());
  }

  @IsTest
  static void patientProvisioningUsesLastNameWhenFirstNameIsMissing() {
    Account account = new Account(Name = 'Provisioning Name Test Account');
    insert account;
    Contact contact = new Contact(
      LastName = 'Patient',
      Email = 'last.name@example.test',
      AccountId = account.Id
    );
    insert contact;
    User portalUser = new User(
      ContactId = contact.Id,
      Email = contact.Email,
      LastName = contact.LastName
    );

    AutocreatedConfigSelfReg1792833096140.provisionPatientForUser(portalUser);

    Patient__c patient = [
      SELECT Name, Portal_Contact__c
      FROM Patient__c
      WHERE Email__c = :contact.Email
    ];
    System.assertEquals('Patient', patient.Name);
    System.assertEquals(contact.Id, patient.Portal_Contact__c);
  }

  @IsTest
  static void registrationProvisioningIsScopedToConfiguredExternalUsers() {
    Account account = new Account(Name = 'Provisioning Scope Test Account');
    Account unrelatedAccount = new Account(
      Name = 'Unrelated Provisioning Test Account'
    );
    insert new List<Account>{ account, unrelatedAccount };
    Contact contact = new Contact(
      LastName = 'Portal Patient',
      AccountId = account.Id
    );
    insert contact;
    Set<Id> registrationAccountIds = new Set<Id>{ account.Id };

    User portalUser = new User(
      Id = UserInfo.getUserId(),
      ContactId = contact.Id
    );
    User standardUser = [
      SELECT Id, UserType
      FROM User
      WHERE Id = :UserInfo.getUserId()
    ];
    standardUser.ContactId = contact.Id;

    System.assert(
      AutocreatedConfigSelfReg1792833096140.isRegisteredPatientPortalUser(
        portalUser,
        account.Id,
        registrationAccountIds
      )
    );
    System.assertEquals(
      new List<Id>{ portalUser.Id },
      AutocreatedConfigSelfReg1792833096140.getRegisteredPatientUserIds(
        new List<User>{ portalUser },
        registrationAccountIds
      )
    );
    System.assertEquals(
      false,
      AutocreatedConfigSelfReg1792833096140.isRegisteredPatientPortalUser(
        portalUser,
        unrelatedAccount.Id,
        registrationAccountIds
      )
    );
    System.assertEquals(
      false,
      AutocreatedConfigSelfReg1792833096140.isRegisteredPatientPortalUser(
        standardUser,
        account.Id,
        registrationAccountIds
      )
    );
    System.assertEquals(
      0,
      AutocreatedConfigSelfReg1792833096140.getRegisteredPatientUserIds(
          new List<User>{ portalUser },
          new Set<Id>{ unrelatedAccount.Id }
        )
        .size()
    );
    System.assertEquals(
      0,
      AutocreatedConfigSelfReg1792833096140.getRegisteredPatientUserIds(
          new List<User>{ standardUser },
          registrationAccountIds
        )
        .size()
    );
  }

  @IsTest
  static void bulkProvisioningCreatesOnlyOnePatientForDuplicateEmail() {
    Account account = new Account(Name = 'Bulk Provisioning Test Account');
    insert account;
    Contact firstContact = new Contact(
      FirstName = 'First',
      LastName = 'Patient',
      Email = 'bulk.patient@example.test',
      AccountId = account.Id
    );
    Contact duplicateContact = new Contact(
      FirstName = 'Duplicate',
      LastName = 'Patient',
      Email = 'bulk.patient@example.test',
      AccountId = account.Id
    );
    insert new List<Contact>{ firstContact, duplicateContact };

    AutocreatedConfigSelfReg1792833096140.provisionPatientsForUsers(
      new List<User>{
        new User(
          ContactId = firstContact.Id,
          Email = 'BULK.PATIENT@example.test',
          FirstName = 'First',
          LastName = 'Patient'
        ),
        new User(
          ContactId = duplicateContact.Id,
          Email = 'bulk.patient@example.test',
          FirstName = 'Duplicate',
          LastName = 'Patient'
        )
      }
    );

    List<Patient__c> patients = [
      SELECT Id, Email__c, Portal_Contact__c
      FROM Patient__c
      WHERE Email__c = 'bulk.patient@example.test'
    ];
    System.assertEquals(1, patients.size());
    System.assertEquals(firstContact.Id, patients[0].Portal_Contact__c);
  }

  @IsTest
  static void userInsertTriggerAndProvisioningSelectorHandleNewUsers() {
    Account account = new Account(Name = 'Trigger Provisioning Test Account');
    insert account;
    Contact contact = new Contact(
      LastName = 'Trigger Test Patient',
      AccountId = account.Id
    );
    insert contact;

    User portalUser = new User(
      Id = UserInfo.getUserId(),
      ContactId = contact.Id
    );
    AutocreatedConfigSelfReg1792833096140.enqueueProvisioningForUsers(
      new List<User>{ portalUser }
    );

    User standardUser = new User(
      Alias = 'hctest',
      Email = 'trigger.test@example.test',
      EmailEncodingKey = 'UTF-8',
      LastName = 'Trigger Test',
      LanguageLocaleKey = UserInfo.getLocale(),
      LocaleSidKey = UserInfo.getLocale(),
      ProfileId = UserInfo.getProfileId(),
      TimeZoneSidKey = UserInfo.getTimeZone().getID(),
      Username = 'trigger.test.' +
        String.valueOf(DateTime.now().getTime()) +
        '@example.test'
    );
    insert standardUser;
    System.assertNotEquals(null, standardUser.Id);
  }

  @IsTest
  static void doesNotCreatePatientsWithoutAnAccountOrEmail() {
    Contact contactWithoutAccount = new Contact(
      LastName = 'No Account',
      Email = 'no.account@example.test'
    );
    Account account = new Account(Name = 'Missing Email Test Account');
    insert account;
    Contact contactWithoutEmail = new Contact(
      LastName = 'No Email',
      AccountId = account.Id
    );
    insert new List<Contact>{ contactWithoutAccount, contactWithoutEmail };

    System.assertEquals(
      null,
      AutocreatedConfigSelfReg1792833096140.createPatientForContact(
        contactWithoutAccount.Id,
        contactWithoutAccount.Email,
        'No Account'
      )
    );
    System.assertEquals(
      null,
      AutocreatedConfigSelfReg1792833096140.createPatientForContact(
        contactWithoutEmail.Id,
        null,
        'No Email'
      )
    );
  }

  @IsTest
  static void createsAUserAfterRegistrationAttributesAreValidated() {
    Account account = new Account(Name = 'Portal User Test Account');
    insert account;
    Map<Schema.SObjectField, String> attributes = new Map<Schema.SObjectField, String>{
      User.FirstName => 'New',
      User.LastName => 'Registrant',
      User.Email => 'new.registrant@example.test'
    };

    Id userId = new AutocreatedConfigSelfReg1792833096140()
      .createUser(
        account.Id,
        UserInfo.getProfileId(),
        attributes,
        'TestPassword123!'
      );

    System.assertEquals(UserInfo.getUserId(), userId);
    Test.startTest();
    AutocreatedConfigSelfReg1792833096140.provisionRegisteredPatientUser(
      UserInfo.getUserId(),
      account.Id
    );
    Test.stopTest();
  }

  @IsTest
  static void createsAUserWithGeneratedPasswordWhenNoneIsProvided() {
    Account account = new Account(Name = 'Generated Password Test Account');
    insert account;
    Map<Schema.SObjectField, String> attributes = new Map<Schema.SObjectField, String>{
      User.LastName => 'Registrant',
      User.Email => 'generated.password@example.test'
    };

    Id userId = new AutocreatedConfigSelfReg1792833096140()
      .createUser(account.Id, UserInfo.getProfileId(), attributes, null);

    System.assertEquals(UserInfo.getUserId(), userId);
  }

  @IsTest
  static void generatedPasswordAddsAllMissingCharacterTypes() {
    String completedPassword = AutocreatedConfigSelfReg1792833096140.addMissingPasswordRequirements(
      'base',
      true,
      true,
      true,
      true,
      new List<String>{ 'b' },
      new List<String>{ 'A' },
      new List<String>{ '1' },
      new List<String>{ '!' }
    );

    System.assertEquals('basebA1!', completedPassword);
  }

  @IsTest
  static void rejectsMissingRegistrationRequirementsWithoutCreatingAUser() {
    Id userId = new AutocreatedConfigSelfReg1792833096140()
      .createUser(
        null,
        UserInfo.getProfileId(),
        new Map<Schema.SObjectField, String>(),
        null
      );

    System.assertEquals(null, userId);
  }

  @IsTest
  static void rejectsMissingProfileAttributesAndEmailOrLastName() {
    Account account = new Account(Name = 'Invalid Registration Test Account');
    insert account;
    AutocreatedConfigSelfReg1792833096140 handler = new AutocreatedConfigSelfReg1792833096140();

    System.assertEquals(
      null,
      handler.createUser(
        account.Id,
        null,
        new Map<Schema.SObjectField, String>(),
        null
      )
    );
    System.assertEquals(
      null,
      handler.createUser(account.Id, UserInfo.getProfileId(), null, null)
    );
    System.assertEquals(
      null,
      handler.createUser(
        account.Id,
        UserInfo.getProfileId(),
        new Map<Schema.SObjectField, String>{ User.LastName => 'Registrant' },
        null
      )
    );
    System.assertEquals(
      null,
      handler.createUser(
        account.Id,
        UserInfo.getProfileId(),
        new Map<Schema.SObjectField, String>{
          User.Email => 'missing.last@example.test'
        },
        null
      )
    );
  }

  @IsTest
  static void rejectsAnEmailAlreadyUsedByAUserWithoutDisclosingTheAccount() {
    User currentUser = [
      SELECT Email
      FROM User
      WHERE Id = :UserInfo.getUserId()
    ];
    Account account = new Account(Name = 'Duplicate Registration Test Account');
    insert account;
    Map<Schema.SObjectField, String> attributes = new Map<Schema.SObjectField, String>{
      User.LastName => 'Registrant',
      User.Email => currentUser.Email
    };

    Id userId = new AutocreatedConfigSelfReg1792833096140()
      .createUser(account.Id, UserInfo.getProfileId(), attributes, null);

    System.assertEquals(null, userId);
  }

  @IsTest
  static void allowsRegistrationWhenOnlyAnInactiveUserHasTheEmail() {
    User inactiveUser = new User(
      Alias = 'hcold',
      Email = 'inactive.registration@example.test',
      EmailEncodingKey = 'UTF-8',
      LastName = 'Inactive',
      LanguageLocaleKey = UserInfo.getLocale(),
      LocaleSidKey = UserInfo.getLocale(),
      ProfileId = UserInfo.getProfileId(),
      TimeZoneSidKey = UserInfo.getTimeZone().getID(),
      Username = 'inactive.registration.' +
        String.valueOf(DateTime.now().getTime()) +
        '@example.test'
    );
    insert inactiveUser;
    inactiveUser.IsActive = false;
    update inactiveUser;

    Account account = new Account(Name = 'Inactive User Registration Test');
    System.runAs(new User(Id = UserInfo.getUserId())) {
      insert account;
    }
    Map<Schema.SObjectField, String> attributes = new Map<Schema.SObjectField, String>{
      User.LastName => 'Registrant',
      User.Email => inactiveUser.Email
    };

    Id userId = new AutocreatedConfigSelfReg1792833096140()
      .createUser(account.Id, UserInfo.getProfileId(), attributes, null);

    System.assertEquals(
      UserInfo.getUserId(),
      userId,
      'An inactive user with a different username must not block registration.'
    );
  }
}
