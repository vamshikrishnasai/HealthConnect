trigger HealthConnectPatientProvisioningEvent on HealthConnect_Patient_Provisioning__e(
  after insert
) {
  HCPatientProvisioningEventHandler.handle(Trigger.new);
}
