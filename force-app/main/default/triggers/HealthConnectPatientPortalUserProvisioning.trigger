trigger HealthConnectPatientPortalUserProvisioning on User(after insert) {
  AutocreatedConfigSelfReg1792833096140.enqueueProvisioningForUsers(Trigger.new);
}
