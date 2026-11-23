@IsTest
private class HealthConnectPatientDashboardTest {
  @TestSetup
  static void createAssignedDoctor() {
    insert new User(
      Alias = 'hcdoc',
      Email = 'healthconnect-doctor@example.com',
      EmailEncodingKey = 'UTF-8',
      LastName = 'Test Doctor',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = UserInfo.getProfileId(),
      TimeZoneSidKey = 'America/Los_Angeles',
      Username = 'healthconnect-dashboard-' +
        DateTime.now().getTime() +
        '@example.com'
    );
  }

  @IsTest
  static void createsOnePatientForTheVerifiedCurrentUsersContact() {
    Account registrationAccount = new Account(
      Name = 'Patient First Login Registration Account'
    );
    insert registrationAccount;
    Contact portalContact = new Contact(
      FirstName = 'First Login',
      LastName = 'Patient',
      Email = 'first.login.patient@example.test',
      AccountId = registrationAccount.Id
    );
    insert portalContact;
    User currentUser = new User(
      Id = UserInfo.getUserId(),
      ContactId = portalContact.Id,
      Email = 'first.login.patient@example.test'
    );

    Test.startTest();
    Id patientId = HealthConnectPatientDashboardController.ensurePatientForCurrentUser(
      currentUser,
      portalContact,
      registrationAccount.Id
    );
    Test.stopTest();

    Patient__c patient = [
      SELECT Id, Name, Email__c, Patient_Status__c, Portal_Contact__c
      FROM Patient__c
      WHERE Id = :patientId
    ];
    System.assertEquals('First Login Patient', patient.Name);
    System.assertEquals('first.login.patient@example.test', patient.Email__c);
    System.assertEquals('Active', patient.Patient_Status__c);
    System.assertEquals(portalContact.Id, patient.Portal_Contact__c);
  }

  @IsTest
  static void returnsExistingPatientAndRepeatedCallsStayIdempotent() {
    Account registrationAccount = new Account(
      Name = 'Patient Idempotency Registration Account'
    );
    insert registrationAccount;
    Contact portalContact = new Contact(
      FirstName = 'Repeat',
      LastName = 'Patient',
      Email = 'repeat.patient@example.test',
      AccountId = registrationAccount.Id
    );
    insert portalContact;
    Patient__c existingPatient = new Patient__c(
      Name = 'Existing Patient',
      Email__c = 'repeat.patient@example.test',
      Portal_Contact__c = portalContact.Id
    );
    insert existingPatient;
    User currentUser = new User(
      Id = UserInfo.getUserId(),
      ContactId = portalContact.Id,
      Email = 'repeat.patient@example.test'
    );

    Id firstResult = HealthConnectPatientDashboardController.ensurePatientForCurrentUser(
      currentUser,
      portalContact,
      registrationAccount.Id
    );
    Id secondResult = HealthConnectPatientDashboardController.ensurePatientForCurrentUser(
      currentUser,
      portalContact,
      registrationAccount.Id
    );

    System.assertEquals(existingPatient.Id, firstResult);
    System.assertEquals(existingPatient.Id, secondResult);
    System.assertEquals(
      1,
      [
        SELECT COUNT()
        FROM Patient__c
        WHERE Portal_Contact__c = :portalContact.Id
      ]
    );
  }

  @IsTest
  static void rejectsMissingContactForCurrentUser() {
    Boolean rejected = false;
    try {
      HealthConnectPatientDashboardController.ensurePatientForCurrentUser();
    } catch (AuraHandledException expectedError) {
      rejected = true;
    }

    System.assert(
      rejected,
      'A user without a Contact must not be provisioned.'
    );
  }

  @IsTest
  static void rejectsContactOutsideConfiguredRegistrationAccount() {
    Account contactAccount = new Account(
      Name = 'Patient Wrong Contact Account'
    );
    Account registrationAccount = new Account(
      Name = 'Patient Expected Registration Account'
    );
    insert new List<Account>{ contactAccount, registrationAccount };
    Contact portalContact = new Contact(
      LastName = 'Wrong Account',
      AccountId = contactAccount.Id
    );
    insert portalContact;
    User currentUser = new User(
      Id = UserInfo.getUserId(),
      ContactId = portalContact.Id,
      Email = 'wrong.account.patient@example.test'
    );

    Boolean rejected = false;
    try {
      HealthConnectPatientDashboardController.ensurePatientForCurrentUser(
        currentUser,
        portalContact,
        registrationAccount.Id
      );
    } catch (AuraHandledException expectedError) {
      rejected = true;
    }

    System.assert(rejected);
    System.assertEquals(0, [SELECT COUNT() FROM Patient__c]);
  }

  @IsTest
  static void rejectsAnotherUsersIdentity() {
    User anotherUser = [
      SELECT Id
      FROM User
      WHERE Alias = 'hcdoc'
      LIMIT 1
    ];

    Boolean rejected = false;
    try {
      HealthConnectPatientDashboardController.ensurePatientForCurrentUser(
        anotherUser,
        null,
        null
      );
    } catch (AuraHandledException expectedError) {
      rejected = true;
    }

    System.assert(rejected, 'The endpoint must only provision its caller.');
  }

  @IsTest
  static void rejectsExistingDuplicatePatientRecordsForContact() {
    Account registrationAccount = new Account(
      Name = 'Patient Duplicate Detection Account'
    );
    insert registrationAccount;
    Contact portalContact = new Contact(
      LastName = 'Duplicate Patient',
      AccountId = registrationAccount.Id
    );
    insert portalContact;
    insert new List<Patient__c>{
      new Patient__c(
        Name = 'Duplicate One',
        Portal_Contact__c = portalContact.Id
      ),
      new Patient__c(
        Name = 'Duplicate Two',
        Portal_Contact__c = portalContact.Id
      )
    };
    User currentUser = new User(
      Id = UserInfo.getUserId(),
      ContactId = portalContact.Id,
      Email = 'duplicate.patient@example.test'
    );

    Boolean rejected = false;
    try {
      HealthConnectPatientDashboardController.ensurePatientForCurrentUser(
        currentUser,
        portalContact,
        registrationAccount.Id
      );
    } catch (AuraHandledException expectedError) {
      rejected = true;
    }

    System.assert(rejected);
    System.assertEquals(
      2,
      [
        SELECT COUNT()
        FROM Patient__c
        WHERE Portal_Contact__c = :portalContact.Id
      ]
    );
  }

  @IsTest
  static void returnsOnlyRecordsForTheLinkedPatient() {
    User assignedDoctor = [
      SELECT Id, Name
      FROM User
      WHERE Alias = 'hcdoc'
      LIMIT 1
    ];

    Account account = new Account(Name = 'HealthConnect Test Account');
    insert account;

    Contact portalContact = new Contact(
      FirstName = 'Patient',
      LastName = 'One',
      AccountId = account.Id
    );
    Contact anotherContact = new Contact(
      FirstName = 'Patient',
      LastName = 'Two',
      AccountId = account.Id
    );
    insert new List<Contact>{ portalContact, anotherContact };

    Patient__c linkedPatient = new Patient__c(
      Name = 'Linked Patient',
      Portal_Contact__c = portalContact.Id
    );
    Patient__c unrelatedPatient = new Patient__c(
      Name = 'Unrelated Patient',
      Portal_Contact__c = anotherContact.Id
    );
    insert new List<Patient__c>{ linkedPatient, unrelatedPatient };

    Health_Case__c healthCase = new Health_Case__c(
      Patient__c = linkedPatient.Id,
      Case_Priority__c = 'Medium',
      Case_Status__c = 'New',
      Symptoms__c = 'Persistent cough',
      Diagnosis__c = 'Upper respiratory infection',
      Doctor_Recommendation__c = 'Rest and fluids',
      Follow_up_Date__c = Date.today().addDays(14),
      Assigned_Doctor__c = assignedDoctor.Id
    );
    Health_Case__c closedCase = new Health_Case__c(
      Patient__c = linkedPatient.Id,
      Case_Priority__c = 'Low',
      Case_Status__c = 'Closed'
    );
    Health_Case__c unrelatedCase = new Health_Case__c(
      Patient__c = unrelatedPatient.Id,
      Case_Priority__c = 'Medium',
      Case_Status__c = 'New',
      Diagnosis__c = 'Must not be visible',
      Doctor_Recommendation__c = 'Must not be visible recommendation'
    );
    insert new List<Health_Case__c>{ healthCase, closedCase, unrelatedCase };
    healthCase = [
      SELECT Id, Name
      FROM Health_Case__c
      WHERE Id = :healthCase.Id
    ];
    closedCase = [
      SELECT Id, Name
      FROM Health_Case__c
      WHERE Id = :closedCase.Id
    ];
    List<Health_Case__c> otherPatientCases = new List<Health_Case__c>();
    for (Integer index = 0; index < 6; index++) {
      otherPatientCases.add(
        new Health_Case__c(
          Patient__c = unrelatedPatient.Id,
          Case_Priority__c = 'Medium',
          Case_Status__c = 'New'
        )
      );
    }
    insert otherPatientCases;
    Appointment__c crossPatientRelatedAppointment = new Appointment__c(
      Patient__c = linkedPatient.Id,
      Health_Case__c = otherPatientCases[0].Id,
      Appointment_Date__c = Date.today().addDays(4),
      Appointment_Time__c = '10:00 AM',
      Appointment_Status__c = 'Scheduled'
    );
    Appointment__c todayRescheduledAppointment = new Appointment__c(
      Patient__c = linkedPatient.Id,
      Health_Case__c = otherPatientCases[1].Id,
      Appointment_Date__c = Date.today(),
      Appointment_Time__c = '10:00 AM',
      Appointment_Status__c = 'Rescheduled'
    );
    Appointment__c todayScheduledAppointment = new Appointment__c(
      Patient__c = linkedPatient.Id,
      Health_Case__c = otherPatientCases[2].Id,
      Appointment_Date__c = Date.today(),
      Appointment_Time__c = '11:00 AM',
      Appointment_Status__c = 'Scheduled'
    );
    Appointment__c futureRescheduledAppointment = new Appointment__c(
      Patient__c = linkedPatient.Id,
      Health_Case__c = otherPatientCases[3].Id,
      Appointment_Date__c = Date.today().addDays(5),
      Appointment_Time__c = '10:00 AM',
      Appointment_Status__c = 'Rescheduled'
    );
    Appointment__c futureCancelledAppointment = new Appointment__c(
      Patient__c = linkedPatient.Id,
      Health_Case__c = healthCase.Id,
      Appointment_Date__c = Date.today().addDays(6),
      Appointment_Time__c = '10:00 AM',
      Appointment_Status__c = 'Cancelled'
    );
    Appointment__c futureCompletedAppointment = new Appointment__c(
      Patient__c = linkedPatient.Id,
      Health_Case__c = healthCase.Id,
      Appointment_Date__c = Date.today().addDays(7),
      Appointment_Time__c = '10:00 AM',
      Appointment_Status__c = 'Completed'
    );
    Appointment__c pastScheduledAppointment = new Appointment__c(
      Patient__c = linkedPatient.Id,
      Health_Case__c = otherPatientCases[4].Id,
      Appointment_Date__c = Date.today().addDays(-1),
      Appointment_Time__c = '10:00 AM',
      Appointment_Status__c = 'Scheduled'
    );
    Appointment__c appointmentWithoutDoctorOrRecommendation = new Appointment__c(
      Patient__c = linkedPatient.Id,
      Health_Case__c = closedCase.Id,
      Appointment_Date__c = Date.today().addDays(-3),
      Appointment_Time__c = '10:00 AM',
      Appointment_Status__c = 'Completed'
    );
    Appointment__c futureScheduledAppointment = new Appointment__c(
      Patient__c = linkedPatient.Id,
      Health_Case__c = otherPatientCases[5].Id,
      Appointment_Date__c = Date.today().addDays(8),
      Appointment_Time__c = '10:00 AM',
      Appointment_Status__c = 'Scheduled'
    );
    Appointment__c scheduledAppointment = new Appointment__c(
      Patient__c = linkedPatient.Id,
      Health_Case__c = healthCase.Id,
      Appointment_Date__c = Date.today().addDays(3),
      Appointment_Time__c = '10:00 AM',
      Appointment_Status__c = 'Scheduled',
      Appointment_Notes__c = 'Internal note marker',
      Assigned_Doctor__c = assignedDoctor.Id
    );
    insert new List<Appointment__c>{
      scheduledAppointment,
      appointmentWithoutDoctorOrRecommendation,
      futureScheduledAppointment,
      new Appointment__c(
        Patient__c = unrelatedPatient.Id,
        Health_Case__c = unrelatedCase.Id,
        Appointment_Date__c = Date.today().addDays(2),
        Appointment_Time__c = '10:00 AM',
        Appointment_Status__c = 'Scheduled'
      ),
      crossPatientRelatedAppointment,
      todayRescheduledAppointment,
      todayScheduledAppointment,
      futureRescheduledAppointment,
      futureCancelledAppointment,
      futureCompletedAppointment,
      pastScheduledAppointment
    };
    insert new Care_Reminder__c(
      Name = 'Immunization reminder',
      Patient__c = linkedPatient.Id,
      Reminder_Type__c = 'Immunization',
      Reminder_Status__c = 'Pending',
      Due_Date__c = Date.today().addDays(5),
      Reminder_Notes__c = 'Bring your immunization record'
    );
    insert new List<Immunization__c>{
      new Immunization__c(
        Patient__c = linkedPatient.Id,
        Vaccine_Name__c = 'Test vaccine',
        Dose__c = 'Dose 1',
        Date_Administered__c = Date.today().addDays(-30),
        Next_Due_Date__c = Date.today().addDays(30)
      ),
      new Immunization__c(
        Patient__c = unrelatedPatient.Id,
        Vaccine_Name__c = 'Unrelated vaccine',
        Date_Administered__c = Date.today().addDays(-15)
      )
    };

    Test.startTest();
    HealthConnectPatientDashboardController.DashboardData dashboard = HealthConnectPatientDashboardController.getDashboardForContact(
      portalContact.Id
    );
    Test.stopTest();

    System.assertEquals(linkedPatient.Id, dashboard.patient.Id);
    System.assertEquals(2, dashboard.healthCaseCount);
    System.assertEquals(1, dashboard.activeCaseCount);
    System.assertEquals(1, dashboard.closedCaseCount);
    System.assertEquals(1, dashboard.pendingFollowUpCount);
    System.assertEquals(2, dashboard.healthCases.size());
    String assignedDoctorName = assignedDoctor.Name;
    Boolean matchingCaseFound = false;
    Boolean emptyCaseFound = false;
    for (
      HealthConnectPatientDashboardController.HealthCaseView returnedCase : dashboard.healthCases
    ) {
      System.assertNotEquals('Must not be visible', returnedCase.diagnosis);
      if (returnedCase.diagnosis == 'Upper respiratory infection') {
        matchingCaseFound = true;
        System.assertEquals('New', returnedCase.caseStatus);
        System.assertEquals('Persistent cough', returnedCase.symptoms);
        System.assertEquals(
          'Rest and fluids',
          returnedCase.doctorRecommendation
        );
        System.assertEquals(true, returnedCase.hasAssignedDoctor);
        System.assertEquals(
          assignedDoctorName,
          returnedCase.assignedDoctorName
        );
      } else if (returnedCase.caseStatus == 'Closed') {
        emptyCaseFound = true;
        System.assertEquals(null, returnedCase.symptoms);
        System.assertEquals(null, returnedCase.diagnosis);
        System.assertEquals(null, returnedCase.doctorRecommendation);
      }
    }
    System.assert(
      matchingCaseFound,
      'The patient’s stored case details should be returned.'
    );
    System.assert(
      emptyCaseFound,
      'Cases without optional medical fields should still be returned.'
    );

    System.assertEquals(1, dashboard.immunizations.size());
    System.assertEquals(
      'Test vaccine',
      dashboard.immunizations[0].Vaccine_Name__c
    );
    System.assertEquals(
      Date.today().addDays(-30),
      dashboard.immunizations[0].Date_Administered__c
    );
    System.assertEquals(1, dashboard.immunizationCount);
    System.assertEquals(1, dashboard.upcomingImmunizationCount);
    System.assertEquals(1, dashboard.reminders.size());
    System.assertEquals(
      'Immunization',
      dashboard.reminders[0].Reminder_Type__c
    );
    System.assertEquals('Pending', dashboard.reminders[0].Reminder_Status__c);
    System.assertEquals(
      'Bring your immunization record',
      dashboard.reminders[0].Reminder_Notes__c
    );
    System.assertEquals(1, dashboard.pendingReminderCount);
    System.assertEquals(10, dashboard.appointmentCount);
    System.assertEquals(6, dashboard.upcomingAppointmentCount);
    System.assertEquals(1, dashboard.missedVisitCount);
    System.assertEquals(1, dashboard.missedAppointments.size());
    System.assertEquals(
      pastScheduledAppointment.Id,
      dashboard.missedAppointments[0].Id,
      'Past appointments still marked Scheduled should be reported as missed.'
    );
    System.assertEquals(6, dashboard.upcomingAppointments.size());
    System.assertEquals(1, dashboard.cancelledAppointments.size());
    System.assertEquals(
      futureCancelledAppointment.Id,
      dashboard.cancelledAppointments[0].Id
    );
    System.assertEquals(
      'Cancelled',
      dashboard.cancelledAppointments[0].appointmentStatus
    );
    Set<Id> expectedUpcomingIds = new Set<Id>{
      scheduledAppointment.Id,
      futureScheduledAppointment.Id,
      crossPatientRelatedAppointment.Id,
      todayRescheduledAppointment.Id,
      todayScheduledAppointment.Id,
      futureRescheduledAppointment.Id
    };
    Set<Id> returnedUpcomingIds = new Set<Id>();
    Boolean unrelatedCaseNameHidden = false;
    Boolean appointmentWithoutDetailsFound = false;
    for (
      HealthConnectPatientDashboardController.AppointmentView appointment : dashboard.upcomingAppointments
    ) {
      returnedUpcomingIds.add(appointment.Id);
      System.assert(
        appointment.appointmentDate >= Date.today(),
        'Upcoming appointments must be dated today or later.'
      );
      System.assert(
        new Set<String>{ 'Scheduled', 'Rescheduled' }
          .contains(appointment.appointmentStatus),
        'Upcoming appointments must be Scheduled or Rescheduled.'
      );
      if (appointment.Id == scheduledAppointment.Id) {
        System.assertEquals(true, appointment.hasAssignedDoctor);
        System.assertEquals(assignedDoctorName, appointment.assignedDoctorName);
        System.assertEquals(healthCase.Name, appointment.relatedCaseName);
        System.assertEquals(
          'Rest and fluids',
          appointment.doctorRecommendation
        );
      }
      if (appointment.Id == crossPatientRelatedAppointment.Id) {
        unrelatedCaseNameHidden =
          appointment.relatedCaseName == null &&
          appointment.doctorRecommendation == null;
      }
    }
    System.assertEquals(expectedUpcomingIds, returnedUpcomingIds);
    System.assertEquals(
      2,
      dashboard.pastAppointments.size(),
      'History excludes open past appointments, which are shown as missed visits.'
    );
    Boolean completedAppointmentFound = false;
    for (
      HealthConnectPatientDashboardController.AppointmentView appointment : dashboard.pastAppointments
    ) {
      if (appointment.Id == futureCompletedAppointment.Id) {
        completedAppointmentFound = true;
        System.assertEquals('Completed', appointment.appointmentStatus);
      }
      if (appointment.Id == appointmentWithoutDoctorOrRecommendation.Id) {
        appointmentWithoutDetailsFound = true;
        System.assertEquals(false, appointment.hasAssignedDoctor);
        System.assertEquals(null, appointment.assignedDoctorName);
        System.assertEquals(closedCase.Name, appointment.relatedCaseName);
        System.assertEquals(null, appointment.doctorRecommendation);
      }
    }
    System.assert(
      completedAppointmentFound,
      'Completed appointments within the history window should be returned, even if their scheduled date is today or later.'
    );
    System.assert(
      appointmentWithoutDetailsFound,
      'An appointment with missing optional details should be returned.'
    );
    System.assertEquals(
      dashboard.upcomingAppointmentCount,
      dashboard.upcomingAppointments.size()
    );
    System.assert(
      !JSON.serialize(dashboard).contains('Internal note marker'),
      'Appointment notes must not be exposed in the patient dashboard response.'
    );
    System.assert(
      unrelatedCaseNameHidden,
      'An appointment must not expose a health case belonging to another patient.'
    );
    System.assertEquals(2, dashboard.pastAppointments.size());
    System.assertEquals(0, dashboard.undatedAppointments.size());
  }

  @IsTest
  static void updatesOnlyTheLinkedPatientsDemographicFields() {
    Account account = new Account(Name = 'HealthConnect Profile Test Account');
    insert account;
    Contact portalContact = new Contact(
      LastName = 'Profile Owner',
      AccountId = account.Id
    );
    Contact unrelatedContact = new Contact(
      LastName = 'Other Patient',
      AccountId = account.Id
    );
    insert new List<Contact>{ portalContact, unrelatedContact };

    Patient__c linkedPatient = new Patient__c(
      Name = 'Profile Owner',
      Portal_Contact__c = portalContact.Id,
      Phone_Number__c = '555-0100',
      Address__c = 'Old address',
      State__c = 'Old state',
      District__c = 'Old district',
      Village__c = 'Old village',
      Patient_Status__c = 'Active'
    );
    Patient__c unrelatedPatient = new Patient__c(
      Name = 'Other Patient',
      Portal_Contact__c = unrelatedContact.Id,
      Address__c = 'Unchanged address'
    );
    insert new List<Patient__c>{ linkedPatient, unrelatedPatient };

    Test.startTest();
    Patient__c updatedPatient = HealthConnectPatientDashboardController.updatePatientProfileForContact(
      portalContact.Id,
      'Updated Profile Owner',
      Date.newInstance(1990, 4, 12),
      '555-0101',
      'O+',
      'Female',
      'New address',
      'New state',
      'New district',
      'New village'
    );
    Test.stopTest();

    System.assertEquals(linkedPatient.Id, updatedPatient.Id);
    System.assertEquals('Updated Profile Owner', updatedPatient.Name);
    System.assertEquals(
      Date.newInstance(1990, 4, 12),
      updatedPatient.Date_of_Birth__c
    );
    System.assertEquals('555-0101', updatedPatient.Phone_Number__c);
    System.assertEquals('O+', updatedPatient.Blood_Group__c);
    System.assertEquals('Female', updatedPatient.Gender__c);
    System.assertEquals('New address', updatedPatient.Address__c);
    System.assertEquals('New state', updatedPatient.State__c);
    System.assertEquals('New district', updatedPatient.District__c);
    System.assertEquals('New village', updatedPatient.Village__c);
    System.assertEquals('Active', updatedPatient.Patient_Status__c);

    Patient__c unchangedPatient = [
      SELECT Name, Address__c
      FROM Patient__c
      WHERE Id = :unrelatedPatient.Id
    ];
    System.assertEquals('Other Patient', unchangedPatient.Name);
    System.assertEquals('Unchanged address', unchangedPatient.Address__c);
  }

  @IsTest
  static void rejectsProfileUpdatesWithoutOneLinkedPatient() {
    Account account = new Account(
      Name = 'HealthConnect Profile Access Account'
    );
    insert account;
    Contact noPatientContact = new Contact(
      LastName = 'No Patient',
      AccountId = account.Id
    );
    Contact duplicatePatientContact = new Contact(
      LastName = 'Duplicate Patients',
      AccountId = account.Id
    );
    insert new List<Contact>{ noPatientContact, duplicatePatientContact };
    insert new List<Patient__c>{
      new Patient__c(
        Name = 'Duplicate One',
        Portal_Contact__c = duplicatePatientContact.Id
      ),
      new Patient__c(
        Name = 'Duplicate Two',
        Portal_Contact__c = duplicatePatientContact.Id
      )
    };

    Boolean missingPatientRejected = false;
    Boolean duplicatePatientsRejected = false;
    Test.startTest();
    try {
      HealthConnectPatientDashboardController.updatePatientProfileForContact(
        noPatientContact.Id,
        'Must not save',
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null
      );
    } catch (AuraHandledException expectedError) {
      missingPatientRejected = true;
    }
    try {
      HealthConnectPatientDashboardController.updatePatientProfileForContact(
        duplicatePatientContact.Id,
        'Must not save',
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null
      );
    } catch (AuraHandledException expectedError) {
      duplicatePatientsRejected = true;
    }
    Test.stopTest();

    System.assert(missingPatientRejected);
    System.assert(duplicatePatientsRejected);
  }

  @IsTest
  static void returnsPendingStateForContactsWithoutALinkedPatient() {
    Account account = new Account(Name = 'HealthConnect Test Account');
    insert account;
    Contact portalContact = new Contact(
      LastName = 'Unlinked',
      AccountId = account.Id
    );
    insert portalContact;

    HealthConnectPatientDashboardController.DashboardData dashboard = HealthConnectPatientDashboardController.getDashboardForContact(
      portalContact.Id
    );

    System.assertEquals(true, dashboard.patientSetupPending);
    System.assertEquals(null, dashboard.patient);
    System.assertEquals(0, dashboard.healthCases.size());
    System.assertEquals(0, dashboard.activeCaseCount);
    System.assertEquals(0, dashboard.pendingFollowUpCount);
    System.assertEquals(0, dashboard.immunizations.size());
    System.assertEquals(0, dashboard.upcomingImmunizationCount);
    System.assertEquals(0, dashboard.reminders.size());
    System.assertEquals(0, dashboard.upcomingAppointments.size());
    System.assertEquals(0, dashboard.cancelledAppointments.size());
  }
}
