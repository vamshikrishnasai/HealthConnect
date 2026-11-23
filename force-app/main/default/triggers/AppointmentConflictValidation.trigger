trigger AppointmentConflictValidation on Appointment__c(
  before insert,
  before update
) {
  AppointmentSchedulingConflictHandler.validateNoDoctorTimeConflicts(
    Trigger.new
  );
}
