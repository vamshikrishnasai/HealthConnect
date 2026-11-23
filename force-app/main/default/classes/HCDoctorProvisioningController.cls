public with sharing class HCDoctorProvisioningController {
  private static final String DOCTOR_PROFILE_NAME = 'HealthConnect Doctor Community User';
  private static final String DOCTOR_NETWORK_NAME = 'HealthConnect Doctor Portal';
  private static final String DOCTOR_ACCOUNT_NAME = 'HealthConnect Doctor Portal Account';

  public class ProvisioningResult {
    @AuraEnabled
    public String status { get; set; }
    @AuraEnabled
    public String message { get; set; }
    @AuraEnabled
    public Boolean activationEmailInitiated { get; set; }
  }

  @AuraEnabled(cacheable=true)
  public static Boolean canProvisionDoctorPortalAccounts() {
    return UserInfo.getUserType() == 'Standard' &&
      FeatureManagement.checkPermission('HealthConnect_Doctor_Provisioning');
  }

  @AuraEnabled
  public static ProvisioningResult provisionDoctorPortalAccount(Id doctorId) {
    requireProvisioningAccess();
    if (doctorId == null) {
      throw new AuraHandledException('Select a Doctor record first.');
    }

    Doctor__c doctor = [
      SELECT Id, Name, Email__c, Contact__c, User__c, Provisioning_Status__c
      FROM Doctor__c
      WHERE Id = :doctorId
      LIMIT 1
    ];
    if (doctor.Provisioning_Status__c == 'Disabled') {
      throw new AuraHandledException(
        'This doctor portal account is disabled. Ask an administrator to review the Doctor record.'
      );
    }

    if (doctor.User__c != null) {
      return retryPortalActivation(doctor);
    }

    String email = normalizeEmail(doctor.Email__c);
    if (email == null || !email.contains('@')) {
      markFailed(
        doctor,
        'Enter a valid doctor email address before provisioning.'
      );
      throw new AuraHandledException(
        'Enter a valid doctor email address before provisioning.'
      );
    }
    if (String.isBlank(doctor.Name)) {
      markFailed(doctor, 'Enter the doctor name before provisioning.');
      throw new AuraHandledException(
        'Enter the doctor name before provisioning.'
      );
    }
    if (doctor.Contact__c != null) {
      markFailed(
        doctor,
        'A Contact is already linked without a portal user. Verify the identity and link before retrying.'
      );
      throw new AuraHandledException(
        'A Contact is already linked without a portal user. Verify the identity and link before retrying.'
      );
    }
    if (hasDuplicateDoctor(email, doctor.Id)) {
      markFailed(doctor, 'Another Doctor record uses this email address.');
      throw new AuraHandledException(
        'Another Doctor record uses this email address. Resolve the duplicate before provisioning.'
      );
    }
    if (hasExistingUser(email)) {
      markFailed(
        doctor,
        'A Salesforce user already uses this email or username. Verify the identity before linking.'
      );
      throw new AuraHandledException(
        'A Salesforce user already uses this email or username. Verify the identity before linking.'
      );
    }
    if (hasExistingContact(email)) {
      markFailed(
        doctor,
        'A Contact already uses this email. Verify the identity before linking.'
      );
      throw new AuraHandledException(
        'A Contact already uses this email. Verify the identity before linking.'
      );
    }

    Profile doctorProfile;
    try {
      doctorProfile = getDoctorProfile();
      assertDoctorNetworkIsLive();
    } catch (AuraHandledException error) {
      markFailed(doctor, error.getMessage());
      throw error;
    }

    Id accountId;
    try {
      accountId = getDoctorAccountId();
    } catch (AuraHandledException error) {
      markFailed(doctor, error.getMessage());
      throw error;
    }
    doctor.Provisioning_Status__c = 'Pending';
    doctor.Provisioning_Error__c = null;
    update doctor;

    User portalUser = buildExternalUser(doctor, email, doctorProfile.Id);
    Id userId;
    try {
      userId = insertExternalUser(portalUser, accountId);
    } catch (DmlException error) {
      markFailed(
        doctor,
        'Salesforce could not create the external account. Verify the doctor profile, site membership, and available license.'
      );
      throw new AuraHandledException(
        'Salesforce could not create the external account. Verify the doctor profile, site membership, and available license.'
      );
    }

    if (userId == null) {
      markFailed(
        doctor,
        'Salesforce did not return an external account. Verify the doctor profile, site membership, and available license.'
      );
      throw new AuraHandledException(
        'Salesforce did not return an external account. Verify the doctor profile, site membership, and available license.'
      );
    }

    User createdUser = getCreatedExternalUser(userId);
    if (createdUser.ContactId == null) {
      markFailed(
        doctor,
        'Salesforce created a user without a Contact link. Ask an administrator to investigate before retrying.'
      );
      throw new AuraHandledException(
        'Salesforce created a user without a Contact link. Ask an administrator to investigate before retrying.'
      );
    }

    doctor.Contact__c = createdUser.ContactId;
    doctor.User__c = createdUser.Id;
    doctor.Provisioning_Status__c = 'Pending';
    doctor.Provisioning_Error__c = null;
    update doctor;
    System.enqueueJob(
      new HCDoctorPortalAccessSetupJob(
        doctor.Id,
        createdUser.Id,
        createdUser.ContactId
      )
    );
    return pendingResult();
  }

  private static void requireProvisioningAccess() {
    if (!canProvisionDoctorPortalAccounts()) {
      throw new AuraHandledException(
        'You are not authorized to provision doctor portal accounts.'
      );
    }
  }

  private static Profile getDoctorProfile() {
    List<Profile> profiles = [
      SELECT Id, UserType, UserLicense.Name
      FROM Profile
      WHERE Name = :DOCTOR_PROFILE_NAME
      LIMIT 1
    ];
    if (
      profiles.isEmpty() ||
      profiles[0].UserType != 'PowerCustomerSuccess' ||
      profiles[0].UserLicense.Name != 'Customer Community Plus'
    ) {
      throw new AuraHandledException(
        'The configured doctor portal profile is missing or does not use the Customer Community Plus license.'
      );
    }
    return profiles[0];
  }

  private static void assertDoctorNetworkIsLive() {
    List<Network> doctorNetworks = [
      SELECT Id, Status
      FROM Network
      WHERE Name = :DOCTOR_NETWORK_NAME
      LIMIT 1
    ];
    if (doctorNetworks.isEmpty() || doctorNetworks[0].Status != 'Live') {
      throw new AuraHandledException(
        'The Doctor Experience site is not live yet. Ask an administrator to publish and activate it.'
      );
    }
  }

  private static Id getDoctorAccountId() {
    List<Account> accounts = [
      SELECT Id
      FROM Account
      WHERE Name = :DOCTOR_ACCOUNT_NAME
      LIMIT 2
    ];
    if (accounts.size() != 1) {
      throw new AuraHandledException(
        'Provisioning requires exactly one account named HealthConnect Doctor Portal Account.'
      );
    }
    return accounts[0].Id;
  }

  private static User buildExternalUser(
    Doctor__c doctor,
    String email,
    Id profileId
  ) {
    List<String> nameParts = doctor.Name.trim().split('\\s+');
    String lastName = nameParts.remove(nameParts.size() - 1);
    User portalUser = new User(
      ProfileId = profileId,
      Email = email,
      Username = email,
      LastName = lastName,
      Alias = makeToken().substring(0, 8),
      CommunityNickname = 'hc' + makeToken(),
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = UserInfo.getLocale(),
      LocaleSidKey = UserInfo.getLocale(),
      TimeZoneSidKey = UserInfo.getTimeZone().getID()
    );
    if (!nameParts.isEmpty()) {
      portalUser.FirstName = String.join(nameParts, ' ');
    }
    return portalUser;
  }

  private static Id insertExternalUser(User portalUser, Id accountId) {
    Contact portalContact = new Contact(
      AccountId = accountId,
      FirstName = portalUser.FirstName,
      LastName = portalUser.LastName,
      Email = portalUser.Email
    );
    insert portalContact;
    portalUser.ContactId = portalContact.Id;
    portalUser.IsActive = false;
    insert portalUser;
    return portalUser.Id;
  }

  private static User getCreatedExternalUser(Id userId) {
    return [
      SELECT Id, ContactId
      FROM User
      WHERE Id = :userId
      LIMIT 1
    ];
  }

  private static ProvisioningResult retryPortalActivation(Doctor__c doctor) {
    Profile doctorProfile;
    try {
      doctorProfile = getDoctorProfile();
      assertDoctorNetworkIsLive();
    } catch (AuraHandledException error) {
      markFailed(doctor, error.getMessage());
      throw error;
    }

    User existingUser = [
      SELECT Id, ContactId, Email, ProfileId
      FROM User
      WHERE Id = :doctor.User__c
      LIMIT 1
    ];
    if (
      existingUser.ProfileId != doctorProfile.Id ||
      existingUser.ContactId == null ||
      existingUser.ContactId != doctor.Contact__c ||
      normalizeEmail(existingUser.Email) != normalizeEmail(doctor.Email__c)
    ) {
      throw new AuraHandledException(
        'The linked portal identity does not match this Doctor record. Ask an administrator to verify it.'
      );
    }

    if (doctor.Provisioning_Status__c == 'Pending') {
      return pendingResult();
    }

    doctor.Provisioning_Status__c = 'Pending';
    doctor.Provisioning_Error__c = null;
    update doctor;
    System.enqueueJob(
      new HCDoctorPortalAccessSetupJob(
        doctor.Id,
        existingUser.Id,
        existingUser.ContactId
      )
    );
    return pendingResult();
  }

  private static ProvisioningResult pendingResult() {
    ProvisioningResult result = new ProvisioningResult();
    result.status = 'Pending';
    result.message = 'The external account is created. Portal access and password setup are processing; refresh the Doctor record shortly.';
    result.activationEmailInitiated = false;
    return result;
  }

  private static Boolean hasDuplicateDoctor(String email, Id doctorId) {
    return ![
        SELECT Id
        FROM Doctor__c
        WHERE Id != :doctorId AND Email__c = :email
        LIMIT 1
      ]
      .isEmpty();
  }

  private static Boolean hasExistingUser(String email) {
    return ![
        SELECT Id
        FROM User
        WHERE IsActive= true AND (Email = :email OR Username = :email)
        LIMIT 1
      ]
      .isEmpty();
  }

  private static Boolean hasExistingContact(String email) {
    return ![
        SELECT Id
        FROM Contact
        WHERE Email = :email
        LIMIT 1
      ]
      .isEmpty();
  }

  private static void markFailed(Doctor__c doctor, String message) {
    doctor.Provisioning_Status__c = 'Failed';
    doctor.Provisioning_Error__c = message.left(255);
    update doctor;
  }

  private static String normalizeEmail(String email) {
    return String.isBlank(email) ? null : email.trim().toLowerCase();
  }

  private static String makeToken() {
    return EncodingUtil.convertToHex(Crypto.generateAesKey(128)).toLowerCase();
  }
}
