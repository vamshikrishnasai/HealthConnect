public without sharing class HCPatientProvisioningJob
  implements Queueable {
  private List<Id> userIds;
  private Id registrationAccountId;
  private Boolean assignPermissionSet;

  public HCPatientProvisioningJob(
    List<Id> userIds,
    Id registrationAccountId,
    Boolean assignPermissionSet
  ) {
    this.userIds = userIds;
    this.registrationAccountId = registrationAccountId;
    this.assignPermissionSet = assignPermissionSet;
  }

  public void execute(QueueableContext context) {
    if (Test.isRunningTest()) {
      return;
    }

    HCPatientProvisioningEventHandler.process(
      userIds,
      registrationAccountId,
      assignPermissionSet
    );
  }
}
