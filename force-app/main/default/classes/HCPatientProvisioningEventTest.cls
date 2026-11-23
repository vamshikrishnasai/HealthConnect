@IsTest
private class HCPatientProvisioningEventTest {
  @IsTest
  static void acceptsValidProvisioningEventsWithoutRunningQueueablesInTest() {
    Account account = new Account(
      Name = 'Provisioning Event Handler Test Account'
    );
    insert account;

    HealthConnect_Patient_Provisioning__e provisioningEvent =
      new HealthConnect_Patient_Provisioning__e(
        User_Id__c = String.valueOf(UserInfo.getUserId()),
        Registration_Account_Id__c = String.valueOf(account.Id)
      );

    HCPatientProvisioningEventHandler.handle(
      new List<HealthConnect_Patient_Provisioning__e>{ provisioningEvent }
    );

    System.assertEquals(0, Limits.getQueueableJobs());
  }

  @IsTest
  static void platformEventTriggerAcceptsProvisioningEvents() {
    Account account = new Account(
      Name = 'Provisioning Event Trigger Test Account'
    );
    insert account;
    EventBus.publish(
      new HealthConnect_Patient_Provisioning__e(
        User_Id__c = String.valueOf(UserInfo.getUserId()),
        Registration_Account_Id__c = String.valueOf(account.Id)
      )
    );
    Test.getEventBus().deliver();
  }

  @IsTest
  static void createsPatientAfterValidatingRegistrationAccount() {
    Account account = new Account(
      Name = 'Provisioning Event Patient Test Account'
    );
    insert account;
    Contact contact = new Contact(
      FirstName = 'Event',
      LastName = 'Patient',
      Email = 'event.patient@example.test',
      AccountId = account.Id
    );
    insert contact;

    User portalUserSnapshot = new User(
      Id = UserInfo.getUserId(),
      ContactId = contact.Id,
      Email = contact.Email,
      FirstName = contact.FirstName,
      LastName = contact.LastName
    );

    HCPatientProvisioningEventHandler.processSnapshots(
      new List<User>{ portalUserSnapshot },
      new Map<Id, Contact>{ contact.Id => contact },
      account.Id,
      false
    );

    Patient__c patient = [
      SELECT Email__c, Portal_Contact__c
      FROM Patient__c
      WHERE Portal_Contact__c = :contact.Id
    ];
    System.assertEquals(contact.Email, patient.Email__c);
    System.assertEquals(contact.Id, patient.Portal_Contact__c);
  }

  @IsTest
  static void rejectsContactFromDifferentRegistrationAccount() {
    Account contactAccount = new Account(Name = 'Wrong Contact Account');
    Account registrationAccount = new Account(
      Name = 'Configured Registration Account'
    );
    insert new List<Account>{ contactAccount, registrationAccount };
    Contact contact = new Contact(
      LastName = 'Wrong Account',
      AccountId = contactAccount.Id
    );
    insert contact;

    User portalUserSnapshot = new User(
      Id = UserInfo.getUserId(),
      ContactId = contact.Id,
      Email = 'wrong.account@example.test',
      LastName = 'Wrong Account'
    );

    try {
      HCPatientProvisioningEventHandler.processSnapshots(
        new List<User>{ portalUserSnapshot },
        new Map<Id, Contact>{ contact.Id => contact },
        registrationAccount.Id,
        false
      );
      System.assert(false, 'Expected Account validation to reject the Contact.');
    } catch (
      HCPatientProvisioningEventHandler.ProvisioningEventException caughtException
    ) {
      System.assert(
        caughtException.getMessage().contains(
          'does not belong to the configured patient registration Account'
        )
      );
    }
  }

  @IsTest
  static void rejectsInvalidEventRecordIds() {
    try {
      HCPatientProvisioningEventHandler.handle(
        new List<HealthConnect_Patient_Provisioning__e>{
          new HealthConnect_Patient_Provisioning__e(
            User_Id__c = 'invalid',
            Registration_Account_Id__c = String.valueOf(UserInfo.getUserId())
          )
        }
      );
      System.assert(false, 'Expected invalid event IDs to be rejected.');
    } catch (
      HCPatientProvisioningEventHandler.ProvisioningEventException caughtException
    ) {
      System.assert(
        caughtException.getMessage().contains('invalid record ID')
      );
    }
  }
}
