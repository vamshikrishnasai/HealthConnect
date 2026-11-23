trigger HealthCasePortalContactSync on Health_Case__c (before insert, before update) {
    HealthConnectPatientContactSync.syncHealthCases(Trigger.new);
}
