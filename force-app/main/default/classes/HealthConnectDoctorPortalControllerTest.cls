@IsTest
private class HealthConnectDoctorPortalControllerTest {
  @IsTest
  static void returnsAndUpdatesOnlyCasesAssignedToTheCurrentDoctor() {
    PermissionSet doctorPortalPermission = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = 'HealthConnect_Doctor_Portal'
      LIMIT 1
    ];
    Profile workerProfile = [
      SELECT Id
      FROM Profile
      WHERE Name = 'HealthConnect Health Worker'
      LIMIT 1
    ];
    Profile doctorProfile = [
      SELECT Id
      FROM Profile
      WHERE Name = 'HealthConnect Doctor'
      LIMIT 1
    ];
    String usernameSuffix = String.valueOf(DateTime.now().getTime());
    User worker = new User(
      Alias = 'hcworker',
      Email = 'hc-worker-' + usernameSuffix + '@example.test',
      EmailEncodingKey = 'UTF-8',
      LastName = 'Health Worker',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = workerProfile.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      Username = 'hc-worker-' + usernameSuffix + '@example.test'
    );
    User doctor = new User(
      Alias = 'hcdoctor',
      Email = 'hc-doctor-' + usernameSuffix + '@example.test',
      EmailEncodingKey = 'UTF-8',
      LastName = 'Doctor',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = doctorProfile.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      Username = 'hc-doctor-' + usernameSuffix + '@example.test'
    );
    User anotherDoctor = new User(
      Alias = 'hcothdr',
      Email = 'hc-other-doctor-' + usernameSuffix + '@example.test',
      EmailEncodingKey = 'UTF-8',
      LastName = 'Other Doctor',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = doctorProfile.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      Username = 'hc-other-doctor-' + usernameSuffix + '@example.test'
    );
    User unlinkedDoctor = new User(
      Alias = 'hcunl',
      Email = 'hc-unlinked-doctor-' + usernameSuffix + '@example.test',
      EmailEncodingKey = 'UTF-8',
      LastName = 'Unlinked Doctor',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = doctorProfile.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      Username = 'hc-unlinked-doctor-' + usernameSuffix + '@example.test'
    );
    insert new List<User>{ worker, doctor, anotherDoctor, unlinkedDoctor };
    insert new List<PermissionSetAssignment>{
      new PermissionSetAssignment(
        AssigneeId = doctor.Id,
        PermissionSetId = doctorPortalPermission.Id
      ),
      new PermissionSetAssignment(
        AssigneeId = anotherDoctor.Id,
        PermissionSetId = doctorPortalPermission.Id
      ),
      new PermissionSetAssignment(
        AssigneeId = unlinkedDoctor.Id,
        PermissionSetId = doctorPortalPermission.Id
      )
    };

    Doctor__c doctorRecord = new Doctor__c(
      Name = 'Dr. Doctor',
      User__c = doctor.Id,
      Specialization__c = 'General Physician',
      Email__c = doctor.Email,
      Phone_Number__c = '555-0101',
      Healthcare_Facility__c = 'HealthConnect Clinic',
      District__c = 'Central',
      Availability_Status__c = 'Available'
    );
    Doctor__c otherDoctorRecord = new Doctor__c(
      Name = 'Dr. Other Doctor',
      User__c = anotherDoctor.Id,
      Specialization__c = 'Pediatrician',
      Email__c = anotherDoctor.Email,
      Phone_Number__c = '555-0102',
      Healthcare_Facility__c = 'Other Clinic',
      District__c = 'North',
      Availability_Status__c = 'Unavailable'
    );
    insert new List<Doctor__c>{ doctorRecord, otherDoctorRecord };

    Patient__c assignedPatient = new Patient__c(Name = 'Assigned Patient');
    Patient__c otherPatient = new Patient__c(Name = 'Other Doctor Patient');
    Date expectedFollowUpDate = Date.today().addDays(7);
    Id assignedCaseId;
    Id otherDoctorsCaseId;
    Id assignedAppointmentId;
    System.runAs(worker) {
      insert new List<Patient__c>{ assignedPatient, otherPatient };

      Health_Case__c assignedCase = new Health_Case__c(
        Patient__c = assignedPatient.Id,
        Case_Priority__c = 'Medium',
        Case_Status__c = 'New',
        Symptoms__c = 'Persistent cough',
        Assigned_Doctor__c = doctor.Id
      );
      Health_Case__c otherDoctorsCase = new Health_Case__c(
        Patient__c = otherPatient.Id,
        Case_Priority__c = 'Medium',
        Case_Status__c = 'New',
        Symptoms__c = 'Fever',
        Assigned_Doctor__c = anotherDoctor.Id
      );
      insert new List<Health_Case__c>{ assignedCase, otherDoctorsCase };
      assignedCaseId = assignedCase.Id;
      otherDoctorsCaseId = otherDoctorsCase.Id;
      Appointment__c assignedAppointment = new Appointment__c(
        Patient__c = assignedPatient.Id,
        Health_Case__c = assignedCase.Id,
        Assigned_Doctor__c = doctor.Id,
        Appointment_Date__c = expectedFollowUpDate,
        Appointment_Time__c = '09:00 AM',
        Appointment_Status__c = 'Scheduled'
      );
      Appointment__c otherDoctorsAppointment = new Appointment__c(
        Patient__c = otherPatient.Id,
        Health_Case__c = otherDoctorsCase.Id,
        Assigned_Doctor__c = anotherDoctor.Id,
        Appointment_Date__c = Date.today().addDays(3),
        Appointment_Time__c = '10:00 AM',
        Appointment_Status__c = 'Scheduled'
      );
      insert new List<Appointment__c>{
        assignedAppointment,
        otherDoctorsAppointment
      };
      assignedAppointmentId = assignedAppointment.Id;
    }

    Test.startTest();
    List<HealthConnectDoctorPortalController.AssignedCaseView> assignedCases;
    List<HealthConnectDoctorPortalController.AssignedAppointmentView> appointments;
    Boolean doctorHasPortalAccess;
    HealthConnectDoctorProfileController.DoctorProfileView currentDoctorProfile;
    HealthConnectDoctorProfileController.DoctorProfileView savedDoctorProfile;
    HealthConnectDoctorProfileController.DoctorProfileView otherDoctorProfileView;
    HealthConnectDoctorProfileController.DoctorProfileView unlinkedDoctorProfileView;
    System.runAs(doctor) {
      doctorHasPortalAccess = HealthConnectDoctorPortalController.hasDoctorPortalAccess();
      currentDoctorProfile = HealthConnectDoctorProfileController.getCurrentDoctorProfile();
      savedDoctorProfile = HealthConnectDoctorProfileController.saveCurrentDoctorProfile(
        '555-0199',
        'Other',
        'Updated HealthConnect Clinic',
        'South',
        'Unavailable'
      );
      assignedCases = HealthConnectDoctorPortalController.getAssignedCases();
      appointments = HealthConnectDoctorPortalController.getAssignedAppointments();
      HealthConnectDoctorPortalController.saveRecommendation(
        assignedCaseId,
        'Rest and fluids'
      );
    }
    System.runAs(anotherDoctor) {
      otherDoctorProfileView = HealthConnectDoctorProfileController.getCurrentDoctorProfile();
    }
    System.runAs(unlinkedDoctor) {
      unlinkedDoctorProfileView = HealthConnectDoctorProfileController.getCurrentDoctorProfile();
    }
    Test.stopTest();

    System.assertEquals(
      1,
      assignedCases.size(),
      'Only assigned cases should be returned.'
    );
    System.assertEquals(assignedCaseId, assignedCases[0].Id);
    System.assertEquals('Assigned Patient', assignedCases[0].patientName);
    System.assertEquals(true, doctorHasPortalAccess);
    System.assertEquals('Dr. Doctor', currentDoctorProfile.name);
    System.assertEquals(
      'General Physician',
      currentDoctorProfile.specialization
    );
    System.assertEquals(
      'HealthConnect Clinic',
      currentDoctorProfile.healthcareFacility
    );
    System.assertEquals('Central', currentDoctorProfile.district);
    System.assertEquals('Dr. Doctor', savedDoctorProfile.name);
    System.assertEquals(currentDoctorProfile.email, savedDoctorProfile.email);
    System.assertEquals('555-0199', savedDoctorProfile.phoneNumber);
    System.assertEquals('Other', savedDoctorProfile.specialization);
    System.assertEquals(
      'Updated HealthConnect Clinic',
      savedDoctorProfile.healthcareFacility
    );
    System.assertEquals('South', savedDoctorProfile.district);
    System.assertEquals('Unavailable', savedDoctorProfile.availabilityStatus);
    System.assertEquals('Dr. Other Doctor', otherDoctorProfileView.name);
    System.assertNotEquals(null, unlinkedDoctorProfileView.profileError);
    System.assert(
      unlinkedDoctorProfileView.profileError.contains('no Contact association'),
      'An unlinked login should report when it has no Contact association.'
    );
    System.assertEquals(1, appointments.size());
    System.assertEquals(assignedAppointmentId, appointments[0].Id);

    Boolean invalidSpecializationRejected = false;
    try {
      System.runAs(doctor) {
        HealthConnectDoctorProfileController.saveCurrentDoctorProfile(
          '555-0199',
          'Not a valid specialization',
          'Updated HealthConnect Clinic',
          'South',
          'Unavailable'
        );
      }
    } catch (AuraHandledException expected) {
      invalidSpecializationRejected = true;
    }
    System.assert(
      invalidSpecializationRejected,
      'The profile save must reject values outside the specialization picklist.'
    );

    Boolean unlinkedProfileSaveRejected = false;
    try {
      System.runAs(unlinkedDoctor) {
        HealthConnectDoctorProfileController.saveCurrentDoctorProfile(
          '555-0100',
          'Other',
          'Unauthorized Clinic',
          'West',
          'Available'
        );
      }
    } catch (AuraHandledException expected) {
      unlinkedProfileSaveRejected = true;
    }
    System.assert(
      unlinkedProfileSaveRejected,
      'An unlinked portal account must not update any Doctor profile.'
    );

    Boolean followUpWithoutDateRejected = false;
    try {
      System.runAs(doctor) {
        HealthConnectDoctorPortalController.saveCaseReview(
          assignedCaseId,
          'Respiratory infection',
          'Rest and fluids',
          'Follow-up Required',
          true,
          null,
          null
        );
      }
    } catch (AuraHandledException expected) {
      followUpWithoutDateRejected = true;
    }
    System.assert(
      followUpWithoutDateRejected,
      'The follow-up validation rule must reject a missing follow-up date.'
    );

    System.runAs(doctor) {
      HealthConnectDoctorPortalController.saveCaseReview(
        assignedCaseId,
        'Respiratory infection',
        'Rest and fluids',
        'Follow-up Required',
        true,
        expectedFollowUpDate,
        null
      );
    }

    Health_Case__c savedCase = [
      SELECT
        Doctor_Recommendation__c,
        Diagnosis__c,
        Case_Status__c,
        Appointment_Required__c,
        Follow_up_Date__c
      FROM Health_Case__c
      WHERE Id = :assignedCaseId
    ];
    System.assertEquals('Rest and fluids', savedCase.Doctor_Recommendation__c);
    System.assertEquals('Respiratory infection', savedCase.Diagnosis__c);
    System.assertEquals('Follow-up Required', savedCase.Case_Status__c);
    System.assertEquals(true, savedCase.Appointment_Required__c);
    System.assertEquals(expectedFollowUpDate, savedCase.Follow_up_Date__c);
    Care_Reminder__c followUpReminder = [
      SELECT Id, Appointment__c, OwnerId
      FROM Care_Reminder__c
      WHERE Health_Case__c = :assignedCaseId AND Reminder_Type__c = 'Follow-up'
      LIMIT 1
    ];
    System.assertEquals(assignedAppointmentId, followUpReminder.Appointment__c);
    System.assertEquals(
      worker.Id,
      followUpReminder.OwnerId,
      'A doctor-triggered follow-up reminder should remain owned by the internal case owner.'
    );
    System.assertEquals(
      0,
      [
        SELECT COUNT()
        FROM Care_Reminder__Share
        WHERE
          ParentId = :followUpReminder.Id
          AND UserOrGroupId = :doctor.Id
          AND RowCause = 'Manual'
      ],
      'Doctor-triggered follow-up reminders should not create cross-user shares.'
    );

    Boolean unauthorizedUpdateRejected = false;
    try {
      System.runAs(doctor) {
        HealthConnectDoctorPortalController.saveRecommendation(
          otherDoctorsCaseId,
          'Unauthorized recommendation'
        );
      }
    } catch (AuraHandledException expected) {
      unauthorizedUpdateRejected = true;
    }
    System.assert(
      unauthorizedUpdateRejected,
      'A doctor must not update another doctor’s case.'
    );
  }
}
