trigger PatientPortalContactSync on Patient__c (after update) {
    HealthConnectPatientContactSync.syncChildrenForPatients(Trigger.new, Trigger.oldMap);
}
