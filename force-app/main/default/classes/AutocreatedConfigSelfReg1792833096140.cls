
global without sharing class AutocreatedConfigSelfReg1792833096140
    implements Auth.ConfigurableSelfRegHandler {

    private static final String PORTAL_PERMISSION_SET =
        'HealthConnect_Patient_Portal_Access';

    private static final String PATIENT_NETWORK_NAME =
        'HealthConnect Patient Portal';

    global Id createUser(
        Id accountId,
        Id profileId,
        Map<Schema.SObjectField, String> registrationAttributes,
        String password
    ) {
        if (accountId == null || profileId == null ||
            registrationAttributes == null) {
            return null;
        }

        User portalUser = new User();

        for (Schema.SObjectField field : registrationAttributes.keySet()) {
            portalUser.put(field, registrationAttributes.get(field));
        }

        String email = String.isBlank(portalUser.Email)
            ? null : portalUser.Email.trim().toLowerCase();

        String lastName = String.isBlank(portalUser.LastName)
            ? null : portalUser.LastName.trim();

        if (email == null || lastName == null) {
            return null;
        }

        List<User> existingUsers = [
            SELECT Id
            FROM User
            WHERE IsActive = true
            AND (Email = :email OR Username = :email)
            LIMIT 1
        ];

        if (!existingUsers.isEmpty()) {
            return null;
        }

        portalUser.ProfileId = profileId;
        portalUser.ContactId = null;
        portalUser.Email = email;
        portalUser.Username = email;
        portalUser.LastName = lastName;
        portalUser.Alias = createToken().substring(0, 8);
        portalUser.CommunityNickname = 'hc' + createToken();
        portalUser.EmailEncodingKey = 'UTF-8';
        portalUser.LanguageLocaleKey = UserInfo.getLocale();
        portalUser.LocaleSidKey = UserInfo.getLocale();
        portalUser.TimeZoneSidKey = UserInfo.getTimezone().getID();

        if (String.isBlank(password)) {
            password = generateRandomPassword();
        }

        if (!Test.isRunningTest()) {
            Site.validatePassword(portalUser, password, password);
        }

        Id userId;

        if (Test.isRunningTest()) {
            userId = UserInfo.getUserId();
        } else {
            userId = (Id) Site.createExternalUser(
                portalUser, accountId, password
            );
        }

        return userId;
    }

    public static void enqueueProvisioningForUsers(List<User> users) {
        System.debug(LoggingLevel.ERROR,
            'HC DEBUG: Trigger received users = ' +
            (users == null ? 0 : users.size()));

        if (users == null || users.isEmpty()) {
            return;
        }

        Set<Id> registrationAccountIds =
            getPatientRegistrationAccountIds();

        System.debug(LoggingLevel.ERROR,
            'HC DEBUG: Registration Account IDs = ' +
            registrationAccountIds);

        if (registrationAccountIds.isEmpty()) {
            System.debug(LoggingLevel.ERROR,
                'HC DEBUG: STOPPED - No registration Account found.');
            return;
        }

        List<Id> userIds = new List<Id>();
        List<Id> contactIds = new List<Id>();
        List<String> userTypes = new List<String>();
        List<String> emails = new List<String>();
        List<String> firstNames = new List<String>();
        List<String> lastNames = new List<String>();

        for (User portalUser : users) {
            System.debug(LoggingLevel.ERROR,
                'HC DEBUG: Trigger User = ' + portalUser.Id +
                ', UserType = ' + portalUser.UserType +
                ', ContactId = ' + portalUser.ContactId +
                ', Email = ' + portalUser.Email);

            if (
                portalUser.Id != null &&
                portalUser.UserType != 'Standard' &&
                portalUser.ContactId != null
            ) {
                userIds.add(portalUser.Id);
                contactIds.add(portalUser.ContactId);
                userTypes.add(portalUser.UserType);
                emails.add(portalUser.Email);
                firstNames.add(portalUser.FirstName);
                lastNames.add(portalUser.LastName);
            }
        }

        System.debug(LoggingLevel.ERROR,
            'HC DEBUG: Eligible User count = ' + userIds.size());

        if (userIds.isEmpty()) {
            System.debug(LoggingLevel.ERROR,
                'HC DEBUG: STOPPED - No eligible Users.');
            return;
        }

        List<Id> registrationAccountIdList =
            new List<Id>(registrationAccountIds);

        provisionRegisteredPatientUsers(
            userIds,
            contactIds,
            emails,
            firstNames,
            lastNames,
            registrationAccountIdList
        );

        assignPortalAccessForRegisteredUsers(
            userIds,
            contactIds,
            userTypes,
            registrationAccountIdList
        );
    }

    private static Set<Id> getPatientRegistrationAccountIds() {
        Set<Id> registrationAccountIds = new Set<Id>();

        List<Network> patientNetworks = [
            SELECT Id, Name
            FROM Network
            WHERE Name = :PATIENT_NETWORK_NAME
            LIMIT 1
        ];

        System.debug(LoggingLevel.ERROR,
            'HC DEBUG: Patient Networks found = ' +
            patientNetworks.size());

        if (patientNetworks.isEmpty()) {
            return registrationAccountIds;
        }

        for (NetworkSelfRegistration registration : [
            SELECT AccountId
            FROM NetworkSelfRegistration
            WHERE NetworkId = :patientNetworks[0].Id
            AND AccountId != NULL
        ]) {
            registrationAccountIds.add(registration.AccountId);
        }

        return registrationAccountIds;
    }

    @future
    public static void provisionRegisteredPatientUser(
        Id userId,
        Id registrationAccountId
    ) {
        if (userId == null || registrationAccountId == null) {
            return;
        }

        List<User> registeredUsers = [
            SELECT Id, UserType, ContactId, Email, FirstName, LastName
            FROM User
            WHERE Id = :userId
            LIMIT 1
        ];

        if (
            registeredUsers.isEmpty() ||
            registeredUsers[0].UserType == 'Standard' ||
            registeredUsers[0].ContactId == null
        ) {
            return;
        }

        Contact portalContact = [
            SELECT Id, AccountId
            FROM Contact
            WHERE Id = :registeredUsers[0].ContactId WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (portalContact.AccountId != registrationAccountId) {
            return;
        }

        provisionPatientsForUsers(registeredUsers);
    }

    @future
    public static void provisionRegisteredPatientUsers(
        List<Id> userIds,
        List<Id> contactIds,
        List<String> emails,
        List<String> firstNames,
        List<String> lastNames,
        List<Id> registrationAccountIds
    ) {
        System.debug(LoggingLevel.ERROR,
            'HC DEBUG: FUTURE provisionRegisteredPatientUsers STARTED');

        System.debug(LoggingLevel.ERROR,
            'HC DEBUG: Future User IDs = ' + userIds);

        System.debug(LoggingLevel.ERROR,
            'HC DEBUG: Future Contact IDs = ' + contactIds);

        System.debug(LoggingLevel.ERROR,
            'HC DEBUG: Future Registration Accounts = ' +
            registrationAccountIds);

        if (
            userIds == null ||
            userIds.isEmpty() ||
            contactIds == null ||
            emails == null ||
            firstNames == null ||
            lastNames == null ||
            userIds.size() != contactIds.size() ||
            userIds.size() != emails.size() ||
            userIds.size() != firstNames.size() ||
            userIds.size() != lastNames.size() ||
            registrationAccountIds == null ||
            registrationAccountIds.isEmpty()
        ) {
            System.debug(LoggingLevel.ERROR,
                'HC DEBUG: STOPPED - Invalid future method arguments.');
            return;
        }

        List<User> candidateUsers = new List<User>();

        for (Integer index = 0; index < userIds.size(); index++) {
            candidateUsers.add(
                new User(
                    Id = userIds[index],
                    ContactId = contactIds[index],
                    Email = emails[index],
                    FirstName = firstNames[index],
                    LastName = lastNames[index]
                )
            );
        }

        System.debug(LoggingLevel.ERROR,
            'HC DEBUG: Candidate User count = ' +
            candidateUsers.size());

        List<User> registeredUsers = getRegisteredPatientUsers(
            candidateUsers,
            new Set<Id>(registrationAccountIds)
        );

        System.debug(LoggingLevel.ERROR,
            'HC DEBUG: Accepted registered User count = ' +
            registeredUsers.size());

        if (registeredUsers.isEmpty()) {
            System.debug(LoggingLevel.ERROR,
                'HC DEBUG: STOPPED - No registered Users passed filtering.');
            return;
        }

        provisionPatientsForUsers(registeredUsers);

        System.debug(LoggingLevel.ERROR,
            'HC DEBUG: FUTURE provisionRegisteredPatientUsers FINISHED');
    }

    @TestVisible
    private static List<Id> getRegisteredPatientUserIds(
        List<User> users,
        Set<Id> registrationAccountIds
    ) {
        List<Id> userIdsToProvision = new List<Id>();

        for (User portalUser : getRegisteredPatientUsers(
            users, registrationAccountIds
        )) {
            userIdsToProvision.add(portalUser.Id);
        }

        return userIdsToProvision;
    }

    @TestVisible
    private static List<User> getRegisteredPatientUsers(
        List<User> users,
        Set<Id> registrationAccountIds
    ) {
        List<User> registeredUsers = new List<User>();

        if (
            users == null ||
            users.isEmpty() ||
            registrationAccountIds == null ||
            registrationAccountIds.isEmpty()
        ) {
            return registeredUsers;
        }

        Set<Id> contactIds = new Set<Id>();

        for (User portalUser : users) {
            if (
               
                portalUser.ContactId != null
            ) {
              system.debug('HC DEBUG: Portal User = ' + portalUser.Id +
                ', ContactId = ' + portalUser.ContactId);
                contactIds.add(portalUser.ContactId);
            }
        }

        if (contactIds.isEmpty()) {
            return registeredUsers;
        }

        Map<Id, Contact> contactsById = new Map<Id, Contact>([
            SELECT Id, AccountId
            FROM Contact
            WHERE Id IN :contactIds WITH SYSTEM_MODE
        ]);

        for (User portalUser : users) {
            Contact portalContact = contactsById.get(portalUser.ContactId);

            if (
                portalContact != null &&
                isRegisteredPatientPortalUser(
                    portalUser,
                    portalContact.AccountId,
                    registrationAccountIds
                )
            ) {
                registeredUsers.add(portalUser);
            }
        }

        return registeredUsers;
    }

    @TestVisible
    private static Boolean isRegisteredPatientPortalUser(
        User portalUser,
        Id contactAccountId,
        Set<Id> registrationAccountIds
    ) {
        return portalUser != null &&
            portalUser.UserType != 'Standard' &&
            portalUser.ContactId != null &&
            registrationAccountIds.contains(contactAccountId);
    }

    @future
    public static void provisionPatient(Id userId) {
        provisionPatientsForUsers(new Set<Id>{ userId });
    }

    @future
    public static void provisionRegisteredPatients(List<Id> userIds) {
        provisionPatientsForUsers(new Set<Id>(userIds));
    }

    private static void provisionPatientsForUsers(Set<Id> userIds) {
        if (userIds == null || userIds.isEmpty()) {
            return;
        }

        List<User> registeredUsers = [
            SELECT Id, ContactId, Email, FirstName, LastName
            FROM User
            WHERE Id IN :userIds
        ];

        provisionPatientsForUsers(registeredUsers);
    }

    @TestVisible
    private static void provisionPatientsForUsers(
        List<User> registeredUsers
    ) {
        System.debug(LoggingLevel.ERROR,
            'HC DEBUG: Patient provisioning STARTED');

        System.debug(LoggingLevel.ERROR,
            'HC DEBUG: Registered Users received = ' +
            (registeredUsers == null ? 0 : registeredUsers.size()));

        if (registeredUsers == null || registeredUsers.isEmpty()) {
            System.debug(LoggingLevel.ERROR,
                'HC DEBUG: STOPPED - Registered User list is empty.');
            return;
        }

        Set<Id> contactIds = new Set<Id>();
        Set<String> registrationEmails = new Set<String>();

        for (User registeredUser : registeredUsers) {
            if (
                registeredUser.ContactId != null &&
                !String.isBlank(registeredUser.Email)
            ) {
                contactIds.add(registeredUser.ContactId);
                registrationEmails.add(
                    registeredUser.Email.trim().toLowerCase()
                );
            }
        }

        System.debug(LoggingLevel.ERROR,
            'HC DEBUG: Contact IDs = ' + contactIds);

        System.debug(LoggingLevel.ERROR,
            'HC DEBUG: Registration emails = ' + registrationEmails);

        if (contactIds.isEmpty() || registrationEmails.isEmpty()) {
            System.debug(LoggingLevel.ERROR,
                'HC DEBUG: STOPPED - Missing Contact or Email.');
            return;
        }

        Map<Id, Contact> contactsById = new Map<Id, Contact>([
            SELECT Id, AccountId
            FROM Contact
            WHERE Id IN :contactIds WITH SYSTEM_MODE
        ]);

        System.debug(LoggingLevel.ERROR,
            'HC DEBUG: Contacts found = ' + contactsById.size());

        Set<Id> accountIds = new Set<Id>();

        for (Contact portalContact : contactsById.values()) {
            if (portalContact.AccountId != null) {
                accountIds.add(portalContact.AccountId);
            }
        }

        System.debug(LoggingLevel.ERROR,
            'HC DEBUG: Contact Account IDs = ' + accountIds);

        if (accountIds.isEmpty()) {
            System.debug(LoggingLevel.ERROR,
                'HC DEBUG: STOPPED - No Account IDs found.');
            return;
        }

        List<Account> lockedAccounts = [
            SELECT Id
            FROM Account
            WHERE Id IN :accountIds
            WITH SYSTEM_MODE
            FOR UPDATE
        ];

        System.debug(LoggingLevel.ERROR,
            'HC DEBUG: Locked Accounts found = ' +
            lockedAccounts.size());

        if (lockedAccounts.isEmpty()) {
            System.debug(LoggingLevel.ERROR,
                'HC DEBUG: STOPPED - No Accounts could be locked.');
            return;
        }

        Set<String> existingPatientEmails = new Set<String>();

        for (Patient__c patient : [
            SELECT Email__c
            FROM Patient__c
            WHERE Email__c IN :registrationEmails
        ]) {
            if (!String.isBlank(patient.Email__c)) {
                existingPatientEmails.add(
                    patient.Email__c.trim().toLowerCase()
                );
            }
        }

        System.debug(LoggingLevel.ERROR,
            'HC DEBUG: Existing Patient emails = ' +
            existingPatientEmails);

        List<Patient__c> patientsToInsert = new List<Patient__c>();

        for (User registeredUser : registeredUsers) {
            Contact portalContact = contactsById.get(
                registeredUser.ContactId
            );

            String email = String.isBlank(registeredUser.Email)
                ? null
                : registeredUser.Email.trim().toLowerCase();

            System.debug(LoggingLevel.ERROR,
                'HC DEBUG: Processing User = ' + registeredUser.Id +
                ', Contact = ' + registeredUser.ContactId +
                ', Email = ' + email +
                ', Contact found = ' + (portalContact != null) +
                ', Account = ' +
                (portalContact == null ? null : portalContact.AccountId));

            if (
                portalContact == null ||
                portalContact.AccountId == null ||
                email == null ||
                existingPatientEmails.contains(email)
            ) {
                System.debug(LoggingLevel.ERROR,
                    'HC DEBUG: User skipped = ' + registeredUser.Id);
                continue;
            }

            String patientName = String.isBlank(registeredUser.FirstName)
                ? registeredUser.LastName
                : registeredUser.FirstName + ' ' +
                    registeredUser.LastName;

            patientsToInsert.add(
                new Patient__c(
                    Name = patientName,
                    Email__c = email,
                    Patient_Status__c = 'Active',
                    Portal_Contact__c = portalContact.Id
                )
            );

            existingPatientEmails.add(email);
        }

        System.debug(LoggingLevel.ERROR,
            'HC DEBUG: Patients prepared for insertion = ' +
            patientsToInsert.size());

        if (patientsToInsert.isEmpty()) {
            System.debug(LoggingLevel.ERROR,
                'HC DEBUG: STOPPED - No Patient records prepared.');
            return;
        }

        Database.SaveResult[] results =
            Database.insert(patientsToInsert, false,  AccessLevel.SYSTEM_MODE);

        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) {
                System.debug(LoggingLevel.ERROR,
                    'HC DEBUG: PATIENT CREATED SUCCESSFULLY. ID = ' +
                    results[i].getId());
            } else {
                for (Database.Error err : results[i].getErrors()) {
                    System.debug(LoggingLevel.ERROR,
                        'HC DEBUG: PATIENT INSERT FAILED. ' +
                        'Status = ' + err.getStatusCode() +
                        ', Message = ' + err.getMessage() +
                        ', Fields = ' + err.getFields());
                }
            }
        }

        System.debug(LoggingLevel.ERROR,
            'HC DEBUG: Patient provisioning FINISHED');
    }

    @TestVisible
    private static void provisionPatientForUser(User portalUser) {
        String patientName = String.isBlank(portalUser.FirstName)
            ? portalUser.LastName
            : portalUser.FirstName + ' ' + portalUser.LastName;

        createPatientForContact(
            portalUser.ContactId,
            portalUser.Email,
            patientName
        );
    }

    @future
    public static void assignPortalAccess(Id userId) {
        assignPortalAccessForUsersSync(new Set<Id>{ userId });
    }

    @future
    public static void assignPortalAccessForUsers(List<Id> userIds) {
        assignPortalAccessForUsersSync(new Set<Id>(userIds));
    }

    @future
    public static void assignPortalAccessForRegisteredUsers(
        List<Id> userIds,
        List<Id> contactIds,
        List<String> userTypes,
        List<Id> registrationAccountIds
    ) {
        if (
            userIds == null ||
            userIds.isEmpty() ||
            contactIds == null ||
            userTypes == null ||
            userIds.size() != contactIds.size() ||
            userIds.size() != userTypes.size() ||
            registrationAccountIds == null ||
            registrationAccountIds.isEmpty()
        ) {
            return;
        }

        Set<Id> registrationAccounts = new Set<Id>(
            registrationAccountIds
        );

        Set<Id> contactIdSet = new Set<Id>(contactIds);

        Map<Id, Contact> contactsById = new Map<Id, Contact>([
            SELECT Id, AccountId
            FROM Contact
            WHERE Id IN :contactIdSet WITH SYSTEM_MODE
        ]);

        Set<Id> registeredUserIds = new Set<Id>();

        for (Integer index = 0; index < userIds.size(); index++) {
            Contact portalContact = contactsById.get(contactIds[index]);

            if (
                userTypes[index] != 'Standard' &&
                portalContact != null &&
                registrationAccounts.contains(portalContact.AccountId)
            ) {
                registeredUserIds.add(userIds[index]);
            }
        }

        if (!registeredUserIds.isEmpty()) {
            assignPortalAccessForUsersSync(registeredUserIds);
        }
    }

   
private static void assignPortalAccessForUsersSync(Set<Id> userIds) {
    if (userIds == null || userIds.isEmpty()) {
        return;
    }

    System.debug(LoggingLevel.ERROR,
        'HC DEBUG: Permission assignment started. Users = ' + userIds);

    // Find the patient portal permission set.
    List<PermissionSet> portalPermissionSets = [
        SELECT Id
        FROM PermissionSet
        WHERE Name = :PORTAL_PERMISSION_SET
        WITH SYSTEM_MODE
        LIMIT 1
    ];

    if (portalPermissionSets.isEmpty()) {
        throw new PortalProvisioningException(
            'The HealthConnect patient portal permission set is not available.'
        );
    }

    Id permissionSetId = portalPermissionSets[0].Id;

    // Check which users already have this permission set.
    List<PermissionSetAssignment> existingAssignments = [
        SELECT Id, AssigneeId
        FROM PermissionSetAssignment
        WHERE AssigneeId IN :userIds
        AND PermissionSetId = :permissionSetId
        WITH SYSTEM_MODE
    ];

    Set<Id> assignedUserIds = new Set<Id>();

    for (PermissionSetAssignment assignment : existingAssignments) {
        assignedUserIds.add(assignment.AssigneeId);
    }

    // Prepare assignments only for users who don't already have them.
    List<PermissionSetAssignment> assignmentsToInsert =
        new List<PermissionSetAssignment>();

    for (Id userId : userIds) {
        if (!assignedUserIds.contains(userId)) {
            assignmentsToInsert.add(
                new PermissionSetAssignment(
                    AssigneeId = userId,
                    PermissionSetId = permissionSetId
                )
            );
        }
    }

    if (!assignmentsToInsert.isEmpty()) {
        insert as system assignmentsToInsert;
    }

    System.debug(LoggingLevel.ERROR,
        'HC DEBUG: Permission assignment completed. New assignments = ' +
        assignmentsToInsert.size());
}

    @TestVisible
    private static Id createPatientForContact(
        Id contactId,
        String email,
        String patientName
    ) {
        if (contactId == null || String.isBlank(email)) {
            return null;
        }

        Contact portalContact = [
            SELECT Id, AccountId
            FROM Contact
            WHERE Id = :contactId WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (portalContact.AccountId == null) {
            return null;
        }

        List<Account> registrationAccounts = [
            SELECT Id
            FROM Account
            WHERE Id = :portalContact.AccountId
            WITH SYSTEM_MODE
            LIMIT 1
            FOR UPDATE
        ];

        if (registrationAccounts.isEmpty()) {
            return null;
        }

        String normalizedEmail = email.trim().toLowerCase();

        List<Patient__c> matchingPatients = [
            SELECT Id
            FROM Patient__c
            WHERE Email__c = :normalizedEmail
            LIMIT 1
        ];

        if (!matchingPatients.isEmpty()) {
            return null;
        }

        Patient__c patient = new Patient__c(
            Name = patientName,
            Email__c = normalizedEmail,
            Patient_Status__c = 'Active',
            Portal_Contact__c = portalContact.Id
        );

        insert patient;

        return patient.Id;
    }

    private static String generateRandomPassword() {
        String[] uppercaseChars =
            'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('');

        String[] lowercaseChars =
            'abcdefghijklmnopqrstuvwxyz'.split('');

        String[] numberChars = '1234567890'.split('');
        String[] specialChars = '!#$%-_=+<>'.split('');

        List<String> characters = new List<String>(uppercaseChars);
        characters.addAll(lowercaseChars);
        characters.addAll(numberChars);
        characters.addAll(specialChars);

        String password = '';

        Boolean needsUpper = true;
        Boolean needsLower = true;
        Boolean needsNumber = true;
        Boolean needsSpecial = true;

        while (password.length() < 50) {
            String character = characters[
                generateRandomInt(characters.size())
            ];

            if (needsUpper && character.isAllUpperCase()) {
                needsUpper = false;
            } else if (needsLower && character.isAllLowerCase()) {
                needsLower = false;
            } else if (needsNumber && character.isNumeric()) {
                needsNumber = false;
            } else if (needsSpecial && !character.isAlphanumeric()) {
                needsSpecial = false;
            }

            password += character;
        }

        return addMissingPasswordRequirements(
            password,
            needsLower,
            needsUpper,
            needsNumber,
            needsSpecial,
            lowercaseChars,
            uppercaseChars,
            numberChars,
            specialChars
        );
    }

    @TestVisible
    private static String addMissingPasswordRequirements(
        String password,
        Boolean addLowerCase,
        Boolean addUpperCase,
        Boolean addNumber,
        Boolean addSpecial,
        String[] lowercaseChars,
        String[] uppercaseChars,
        String[] numberChars,
        String[] specialChars
    ) {
        if (addLowerCase) {
            password += lowercaseChars[
                generateRandomInt(lowercaseChars.size())
            ];
        }

        if (addUpperCase) {
            password += uppercaseChars[
                generateRandomInt(uppercaseChars.size())
            ];
        }

        if (addNumber) {
            password += numberChars[
                generateRandomInt(numberChars.size())
            ];
        }

        if (addSpecial) {
            password += specialChars[
                generateRandomInt(specialChars.size())
            ];
        }

        return password;
    }

    private static Integer generateRandomInt(Integer max) {
        return Math.mod(Math.abs(Crypto.getRandomInteger()), max);
    }

    private static String createToken() {
        return EncodingUtil.convertToHex(
            Crypto.generateAesKey(128)
        ).toLowerCase();
    }

    public class PortalProvisioningException extends Exception {
    }
}
