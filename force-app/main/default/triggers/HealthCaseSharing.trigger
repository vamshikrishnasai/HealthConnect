trigger HealthCaseSharing on Health_Case__c (after insert, after update) {
    HealthConnectSharingService.syncHealthCases(Trigger.new, Trigger.isUpdate ? Trigger.oldMap : null);
}
