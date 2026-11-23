@IsTest
private class CareReminderNotificationAttemptTest {
    @TestSetup
    static void createSystemAdministrator() {
        Profile adminProfile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'System Administrator'
            LIMIT 1
        ];
        String uniqueValue = String.valueOf(DateTime.now().getTime());
        insert new User(
            Alias = 'hcadm',
            Email = 'hc-attempt-admin-' + uniqueValue + '@example.test',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Attempt Test Admin',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = adminProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'hc-attempt-admin-' + uniqueValue + '@example.test'
        );
    }

    private static User getAdminUser() {
        return [SELECT Id FROM User WHERE Alias = 'hcadm' LIMIT 1];
    }

    private static Care_Reminder__c createTestReminder(String nameSuffix) {
        Patient__c patient = new Patient__c(Name = 'Attempt Test Patient ' + nameSuffix);
        insert patient;

        Care_Reminder__c reminder = new Care_Reminder__c(
            Name = 'Attempt Test Reminder ' + nameSuffix,
            Patient__c = patient.Id,
            Reminder_Type__c = 'Routine Check-up',
            Reminder_Status__c = 'Pending',
            Due_Date__c = Date.today()
        );
        insert reminder;
        return reminder;
    }

    @IsTest
    static void validAttemptCanBeInserted() {
        User adminUser = getAdminUser();
        Test.startTest();
        System.runAs(adminUser) {
            Care_Reminder__c reminder = createTestReminder('Valid');
            String reminderKey = String.valueOf(reminder.Id);

            Care_Reminder_Notification_Attempt__c attempt =
                new Care_Reminder_Notification_Attempt__c(
                    Care_Reminder__c = reminder.Id,
                    Reminder_Key__c = reminderKey,
                    Attempt_Status__c = 'Reserved',
                    Diagnostic__c = 'Initial reservation'
                );
            Database.SaveResult result = Database.insert(attempt, true, AccessLevel.SYSTEM_MODE);

            System.assertEquals(true, result.isSuccess());
            System.assertNotEquals(null, attempt.Id);

            System.assertEquals(
                1,
                [SELECT count() FROM Care_Reminder_Notification_Attempt__c
                 WHERE Id = :attempt.Id AND Reminder_Key__c = :reminderKey]
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void reservationKeyAllowsOnlyOneAttemptPerReminder() {
        User adminUser = getAdminUser();
        Test.startTest();
        System.runAs(adminUser) {
            Care_Reminder__c reminder = createTestReminder('Duplicate');
            String reminderKey = String.valueOf(reminder.Id);

            Care_Reminder_Notification_Attempt__c firstAttempt =
                new Care_Reminder_Notification_Attempt__c(
                    Care_Reminder__c = reminder.Id,
                    Reminder_Key__c = reminderKey,
                    Attempt_Status__c = 'Reserved'
                );
            Database.insert(firstAttempt, true, AccessLevel.SYSTEM_MODE);

            Care_Reminder_Notification_Attempt__c duplicateAttempt =
                new Care_Reminder_Notification_Attempt__c(
                    Care_Reminder__c = reminder.Id,
                    Reminder_Key__c = reminderKey,
                    Attempt_Status__c = 'Reserved'
                );
            Database.SaveResult duplicateResult =
                Database.insert(duplicateAttempt, false, AccessLevel.SYSTEM_MODE);

            System.assertEquals(false, duplicateResult.isSuccess());
            System.assertEquals(
                StatusCode.DUPLICATE_VALUE,
                duplicateResult.getErrors()[0].getStatusCode()
            );
            System.assertEquals(
                1,
                [SELECT count() FROM Care_Reminder_Notification_Attempt__c
                 WHERE Reminder_Key__c = :reminderKey]
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void attemptWithoutCareReminderIsRejectedByValidationRule() {
        User adminUser = getAdminUser();
        Test.startTest();
        System.runAs(adminUser) {
            String reminderKey = 'NOREM0000000000001';
            Care_Reminder_Notification_Attempt__c attempt =
                new Care_Reminder_Notification_Attempt__c(
                    Care_Reminder__c = null,
                    Reminder_Key__c = reminderKey,
                    Attempt_Status__c = 'Reserved'
                );
            Database.SaveResult result =
                Database.insert(attempt, false, AccessLevel.SYSTEM_MODE);

            System.assertEquals(false, result.isSuccess());
            System.assertEquals(
                StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION,
                result.getErrors()[0].getStatusCode()
            );
            System.assert(
                result.getErrors()[0].getMessage().contains('Care Reminder'),
                'The validation rule must explain that Care Reminder is required.'
            );
            System.assertEquals(
                0,
                [SELECT count() FROM Care_Reminder_Notification_Attempt__c
                 WHERE Reminder_Key__c = :reminderKey]
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void invalidAttemptStatusIsRejectedByRestrictedPicklist() {
        User adminUser = getAdminUser();
        Test.startTest();
        System.runAs(adminUser) {
            Care_Reminder__c reminder = createTestReminder('InvalidStatus');
            String reminderKey = String.valueOf(reminder.Id);

            Care_Reminder_Notification_Attempt__c attempt =
                new Care_Reminder_Notification_Attempt__c(
                    Care_Reminder__c = reminder.Id,
                    Reminder_Key__c = reminderKey,
                    Attempt_Status__c = 'Invalid_Status_Value'
                );
            Database.SaveResult result =
                Database.insert(attempt, false, AccessLevel.SYSTEM_MODE);

            System.assertEquals(false, result.isSuccess());
            System.assertEquals(
                StatusCode.INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST,
                result.getErrors()[0].getStatusCode()
            );
            System.assertEquals(
                0,
                [SELECT count() FROM Care_Reminder_Notification_Attempt__c
                 WHERE Reminder_Key__c = :reminderKey]
            );
        }
        Test.stopTest();
    }
}
