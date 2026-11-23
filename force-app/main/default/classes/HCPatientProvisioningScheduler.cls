public without sharing class HCPatientProvisioningScheduler
  implements Schedulable {
  private static final String PATIENT_NETWORK_NAME =
    'HealthConnect Patient Portal';
  private static final Integer SIGNUP_LOOKBACK_MINUTES = 120;
  @TestVisible
  private static Id testProfileId;
  @TestVisible
  private static Id testRegistrationAccountId;

  public void execute(SchedulableContext context) {
    RegistrationConfig config = getRegistrationConfig();
    if (config == null) {
      throw new SchedulerException(
        'The patient portal Network or its self-registration configuration is missing or ambiguous.'
      );
    }

    Datetime createdAfter = System.now().addMinutes(
      -SIGNUP_LOOKBACK_MINUTES
    );
    List<User> recentUsers = [
      SELECT Id
      FROM User
      WHERE
        ProfileId = :config.profileId
        AND UserType != 'Standard'
        AND ContactId != NULL
        AND Email != NULL
        AND CreatedDate >= :createdAfter
      ORDER BY CreatedDate ASC
      LIMIT 2000
    ];
    if (recentUsers.isEmpty()) {
      return;
    }

    List<Id> userIds = new List<Id>();
    for (User portalUser : recentUsers) {
      userIds.add(portalUser.Id);
    }
    System.enqueueJob(
      new HCPatientProvisioningJob(
        userIds,
        config.registrationAccountId,
        true
      )
    );
  }

  @TestVisible
  private static RegistrationConfig getRegistrationConfig() {
    if (
      Test.isRunningTest() &&
      testProfileId != null &&
      testRegistrationAccountId != null
    ) {
      return new RegistrationConfig(
        testProfileId,
        testRegistrationAccountId
      );
    }

    List<Network> patientNetworks = [
      SELECT Id, SelfRegProfileId
      FROM Network
      WHERE Name = :PATIENT_NETWORK_NAME
      LIMIT 2
    ];
    if (
      patientNetworks.size() != 1 ||
      patientNetworks[0].SelfRegProfileId == null
    ) {
      return null;
    }

    Set<Id> registrationAccountIds = new Set<Id>();
    for (NetworkSelfRegistration registration : [
      SELECT AccountId
      FROM NetworkSelfRegistration
      WHERE
        NetworkId = :patientNetworks[0].Id
        AND AccountId != NULL
    ]) {
      registrationAccountIds.add(registration.AccountId);
    }
    if (registrationAccountIds.size() != 1) {
      return null;
    }
    return new RegistrationConfig(
      patientNetworks[0].SelfRegProfileId,
      new List<Id>(registrationAccountIds)[0]
    );
  }

  private class RegistrationConfig {
    private Id profileId;
    private Id registrationAccountId;

    private RegistrationConfig(Id profileId, Id registrationAccountId) {
      this.profileId = profileId;
      this.registrationAccountId = registrationAccountId;
    }
  }

  public class SchedulerException extends Exception {
  }
}
