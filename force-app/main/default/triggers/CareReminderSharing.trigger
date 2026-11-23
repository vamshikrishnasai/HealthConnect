trigger CareReminderSharing on Care_Reminder__c (after insert, after update) {
    if (!FeatureManagement.checkPermission('HealthConnect_Doctor_Portal')) {
        HealthConnectSharingService.syncRemindersForRecords(
            Trigger.new,
            Trigger.isUpdate ? Trigger.oldMap : null
        );
    }
}
