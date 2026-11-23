@IsTest
private class HCPatientProvisioningSchedulerTest {
  @IsTest
  static void schedulerRunsWithConfiguredProfileAndAccount() {
    Account account = new Account(
      Name = 'Patient Provisioning Scheduler Test Account'
    );
    insert account;
    HCPatientProvisioningScheduler.testProfileId = UserInfo.getProfileId();
    HCPatientProvisioningScheduler.testRegistrationAccountId = account.Id;

    Test.startTest();
    new HCPatientProvisioningScheduler().execute(null);
    Test.stopTest();

    System.assertEquals(0, Limits.getQueueableJobs());
    HCPatientProvisioningScheduler.testProfileId = null;
    HCPatientProvisioningScheduler.testRegistrationAccountId = null;
  }
}
