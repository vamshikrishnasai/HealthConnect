trigger AppointmentSharing on Appointment__c (after insert, after update) {
    HealthConnectSharingService.syncAppointmentsForRecords(
        Trigger.new,
        Trigger.isUpdate ? Trigger.oldMap : null
    );
}
