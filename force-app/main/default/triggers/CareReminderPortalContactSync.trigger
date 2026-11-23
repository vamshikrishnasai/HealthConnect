trigger CareReminderPortalContactSync on Care_Reminder__c (before insert, before update) {
    HealthConnectPatientContactSync.syncCareReminders(Trigger.new);
}
