@IsTest
private class AppointmentSchedulingConflictHandlerTest {
  private static Appointment__c makeAppointment(
    Id patientId,
    Id healthCaseId,
    Date appointmentDate,
    String status
  ) {
    return new Appointment__c(
      Patient__c = patientId,
      Health_Case__c = healthCaseId,
      Assigned_Doctor__c = UserInfo.getUserId(),
      Appointment_Date__c = appointmentDate,
      Appointment_Time__c = '10:00 AM',
      Appointment_Status__c = status
    );
  }

  @IsTest
  static void rejectsAnotherActiveAppointmentForSameDoctorAndTime() {
    Patient__c patient = new Patient__c(Name = 'Conflict Test Patient');
    insert patient;
    Health_Case__c healthCase = new Health_Case__c(
      Patient__c = patient.Id,
      Case_Priority__c = 'Medium',
      Case_Status__c = 'New'
    );
    insert healthCase;

    Date appointmentDate = Date.today().addDays(5);
    insert makeAppointment(
      patient.Id,
      healthCase.Id,
      appointmentDate,
      'Scheduled'
    );

    Appointment__c duplicate = makeAppointment(
      patient.Id,
      healthCase.Id,
      appointmentDate,
      'Scheduled'
    );
    Test.startTest();
    Database.SaveResult duplicateResult = Database.insert(duplicate, false);
    Test.stopTest();

    System.assertEquals(false, duplicateResult.isSuccess());
    System.assert(
      duplicateResult.getErrors()[0]
        .getMessage()
        .contains('already has an appointment scheduled')
    );

    Appointment__c rescheduledDuplicate = makeAppointment(
      patient.Id,
      healthCase.Id,
      appointmentDate,
      'Rescheduled'
    );
    Database.SaveResult rescheduledResult = Database.insert(
      rescheduledDuplicate,
      false
    );
    System.assertEquals(false, rescheduledResult.isSuccess());
  }

  @IsTest
  static void allowsCancelledAndCompletedAppointmentsToReleaseSlot() {
    Patient__c patient = new Patient__c(Name = 'Released Slot Patient');
    insert patient;
    Health_Case__c healthCase = new Health_Case__c(
      Patient__c = patient.Id,
      Case_Priority__c = 'Medium',
      Case_Status__c = 'New'
    );
    insert healthCase;

    Date appointmentDate = Date.today().addDays(6);
    insert new List<Appointment__c>{
      makeAppointment(patient.Id, healthCase.Id, appointmentDate, 'Cancelled'),
      makeAppointment(patient.Id, healthCase.Id, appointmentDate, 'Completed')
    };
    Appointment__c scheduled = makeAppointment(
      patient.Id,
      healthCase.Id,
      appointmentDate,
      'Scheduled'
    );

    Test.startTest();
    insert scheduled;
    Test.stopTest();

    System.assertNotEquals(null, scheduled.Id);
  }

  @IsTest
  static void allowsAnotherAppointmentForHealthCaseAfterCompletionOrCancellation() {
    Patient__c patient = new Patient__c(Name = 'Repeat Visit Patient');
    insert patient;
    Health_Case__c healthCase = new Health_Case__c(
      Patient__c = patient.Id,
      Case_Priority__c = 'Medium',
      Case_Status__c = 'New'
    );
    insert healthCase;
    Date appointmentDate = Date.today().addDays(8);

    insert makeAppointment(
      patient.Id,
      healthCase.Id,
      appointmentDate,
      'Completed'
    );
    insert makeAppointment(
      patient.Id,
      healthCase.Id,
      appointmentDate.addDays(1),
      'Cancelled'
    );
    Appointment__c nextAppointment = makeAppointment(
      patient.Id,
      healthCase.Id,
      appointmentDate.addDays(2),
      'Scheduled'
    );

    Test.startTest();
    insert nextAppointment;
    Test.stopTest();

    System.assertNotEquals(null, nextAppointment.Id);
  }

  @IsTest
  static void rejectsAnotherActiveAppointmentForSameHealthCaseAtDifferentTime() {
    Patient__c patient = new Patient__c(Name = 'Single Active Case Patient');
    insert patient;
    Health_Case__c healthCase = new Health_Case__c(
      Patient__c = patient.Id,
      Case_Priority__c = 'Medium',
      Case_Status__c = 'New'
    );
    insert healthCase;
    Date appointmentDate = Date.today().addDays(9);
    insert makeAppointment(
      patient.Id,
      healthCase.Id,
      appointmentDate,
      'Scheduled'
    );

    Appointment__c secondAppointment = makeAppointment(
      patient.Id,
      healthCase.Id,
      appointmentDate.addDays(1),
      'Scheduled'
    );

    Test.startTest();
    Database.SaveResult result = Database.insert(secondAppointment, false);
    Test.stopTest();

    System.assertEquals(false, result.isSuccess());
    System.assert(
      result.getErrors()[0]
        .getMessage()
        .contains('already has an active appointment')
    );
  }

  @IsTest
  static void rejectsDuplicateSlotsWithinOneBulkRequest() {
    Patient__c patient = new Patient__c(Name = 'Bulk Conflict Patient');
    insert patient;
    Health_Case__c healthCase = new Health_Case__c(
      Patient__c = patient.Id,
      Case_Priority__c = 'Medium',
      Case_Status__c = 'New'
    );
    insert healthCase;

    Date appointmentDate = Date.today().addDays(7);
    List<Appointment__c> appointments = new List<Appointment__c>{
      makeAppointment(patient.Id, healthCase.Id, appointmentDate, 'Scheduled'),
      makeAppointment(patient.Id, healthCase.Id, appointmentDate, 'Scheduled')
    };

    Test.startTest();
    Database.SaveResult[] results = Database.insert(appointments, false);
    Test.stopTest();

    System.assertEquals(false, results[0].isSuccess());
    System.assertEquals(false, results[1].isSuccess());
  }

  @IsTest
  static void rejectsActiveAppointmentsForOneCaseInSameBulkRequest() {
    Patient__c patient = new Patient__c(Name = 'Bulk Case Appointment Patient');
    insert patient;
    Health_Case__c healthCase = new Health_Case__c(
      Patient__c = patient.Id,
      Case_Priority__c = 'Medium',
      Case_Status__c = 'New'
    );
    insert healthCase;
    Date appointmentDate = Date.today().addDays(10);
    List<Appointment__c> appointments = new List<Appointment__c>{
      makeAppointment(patient.Id, healthCase.Id, appointmentDate, 'Scheduled'),
      makeAppointment(
        patient.Id,
        healthCase.Id,
        appointmentDate.addDays(1),
        'Rescheduled'
      )
    };

    Test.startTest();
    Database.SaveResult[] results = Database.insert(appointments, false);
    Test.stopTest();

    System.assertEquals(false, results[0].isSuccess());
    System.assertEquals(false, results[1].isSuccess());
  }
}
