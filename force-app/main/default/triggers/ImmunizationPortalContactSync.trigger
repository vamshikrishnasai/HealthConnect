trigger ImmunizationPortalContactSync on Immunization__c (before insert, before update) {
    HealthConnectPatientContactSync.syncImmunizations(Trigger.new);
}
