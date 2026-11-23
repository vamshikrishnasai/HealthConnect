public without sharing class HCPatientProvisioningEventHandler {
  public static void handle(
    List<HealthConnect_Patient_Provisioning__e> events
  ) {
    if (events == null || events.isEmpty()) {
      return;
    }

    Set<Id> userIds = new Set<Id>();
    Id registrationAccountId;
    for (HealthConnect_Patient_Provisioning__e provisioningEvent : events) {
      Id eventAccountId = parseId(
        provisioningEvent.Registration_Account_Id__c
      );
      Id userId = parseId(provisioningEvent.User_Id__c);
      if (eventAccountId == null || userId == null) {
        throw new ProvisioningEventException(
          'A patient provisioning event is missing its User or registration Account ID.'
        );
      }
      if (
        registrationAccountId != null &&
        registrationAccountId != eventAccountId
      ) {
        throw new ProvisioningEventException(
          'A provisioning event batch contains multiple registration Accounts.'
        );
      }
      registrationAccountId = eventAccountId;
      userIds.add(userId);
    }

    if (!Test.isRunningTest()) {
      System.enqueueJob(
        new HCPatientProvisioningJob(
          new List<Id>(userIds),
          registrationAccountId,
          true
        )
      );
    }
  }

  public static void process(
    List<Id> userIds,
    Id registrationAccountId,
    Boolean assignPermissionSet
  ) {
    if (
      userIds == null ||
      userIds.isEmpty() ||
      registrationAccountId == null
    ) {
      throw new ProvisioningEventException(
        'Patient provisioning requires User IDs and a registration Account ID.'
      );
    }

    Set<Id> requestedUserIds = new Set<Id>(userIds);
    List<User> users = [
      SELECT Id, UserType, ContactId, Email, FirstName, LastName
      FROM User
      WHERE Id IN :requestedUserIds
    ];
    if (users.size() != requestedUserIds.size()) {
      throw new ProvisioningEventException(
        'A registered User could not be found while processing patient provisioning.'
      );
    }

    Set<Id> contactIds = new Set<Id>();
    for (User portalUser : users) {
      if (portalUser.UserType == 'Standard') {
        throw new ProvisioningEventException(
          'An internal User was included in patient registration provisioning.'
        );
      }
      if (portalUser.ContactId == null || String.isBlank(portalUser.Email)) {
        throw new ProvisioningEventException(
          'The registered portal User is missing its Contact or email.'
        );
      }
      contactIds.add(portalUser.ContactId);
    }

    Map<Id, Contact> contactsById = new Map<Id, Contact>(
      [
        SELECT Id, AccountId
        FROM Contact
        WHERE Id IN :contactIds
      ]
    );
    processSnapshots(
      users,
      contactsById,
      registrationAccountId,
      assignPermissionSet
    );
  }

  @TestVisible
  private static void processSnapshots(
    List<User> users,
    Map<Id, Contact> contactsById,
    Id registrationAccountId,
    Boolean assignPermissionSet
  ) {
    if (
      users == null ||
      users.isEmpty() ||
      contactsById == null ||
      registrationAccountId == null
    ) {
      throw new ProvisioningEventException(
        'Patient provisioning requires registered Users and verified Contacts.'
      );
    }

    List<Id> eligibleUserIds = new List<Id>();
    List<Id> eligibleContactIds = new List<Id>();
    List<Id> eligibleContactAccountIds = new List<Id>();
    List<String> emails = new List<String>();
    List<String> firstNames = new List<String>();
    List<String> lastNames = new List<String>();
    for (User portalUser : users) {
      Contact portalContact = contactsById.get(portalUser.ContactId);
      if (
        portalContact == null ||
        portalContact.AccountId != registrationAccountId
      ) {
        throw new ProvisioningEventException(
          'The registered portal Contact does not belong to the configured patient registration Account.'
        );
      }
      eligibleUserIds.add(portalUser.Id);
      eligibleContactIds.add(portalContact.Id);
      eligibleContactAccountIds.add(portalContact.AccountId);
      emails.add(portalUser.Email);
      firstNames.add(portalUser.FirstName);
      lastNames.add(portalUser.LastName);
    }

    AutocreatedConfigSelfReg1792833096140.provisionPatientSnapshotsInTrustedContext(
      eligibleUserIds,
      eligibleContactIds,
      eligibleContactAccountIds,
      emails,
      firstNames,
      lastNames,
      new List<Id>{ registrationAccountId }
    );
    if (assignPermissionSet) {
      AutocreatedConfigSelfReg1792833096140.assignPortalAccessInTrustedContext(
        new Set<Id>(eligibleUserIds)
      );
    }
  }

  private static Id parseId(String rawId) {
    if (String.isBlank(rawId)) {
      return null;
    }
    try {
      return Id.valueOf(rawId);
    } catch (StringException caughtException) {
      throw new ProvisioningEventException(
        'A patient provisioning event contains an invalid record ID.'
      );
    }
  }

  public class ProvisioningEventException extends Exception {
  }
}
