trigger HealthConnectAccessGrantGuard on HealthConnect_Access_Grant__c (before insert, before update, before delete) {
    if (!HealthConnectSharingService.isGrantMutationInProgress()) {
        List<SObject> recordsToBlock = Trigger.isDelete ? Trigger.old : Trigger.new;
        for (SObject grant : recordsToBlock) {
            grant.addError('Access grant records are managed by HealthConnect automation.');
        }
    }
}
