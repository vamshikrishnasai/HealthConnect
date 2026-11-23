trigger AppointmentPortalContactSync on Appointment__c (before insert, before update) {
    HealthConnectPatientContactSync.syncAppointments(Trigger.new);
}
