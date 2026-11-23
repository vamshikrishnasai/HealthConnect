@IsTest
private class CareReminderProcessingTest {
    @TestSetup
    static void createPatient() {
        insert new Patient__c(Name = 'Care Reminder Processing Test Patient');
    }

    @IsTest
    static void acceptsPendingRemindersForEverySupportedType() {
        Patient__c patient = [SELECT Id FROM Patient__c LIMIT 1];
        List<Care_Reminder__c> reminders = new List<Care_Reminder__c>{
            new Care_Reminder__c(
                Name = 'Follow-up',
                Patient__c = patient.Id,
                Reminder_Type__c = 'Follow-up',
                Reminder_Status__c = 'Pending',
                Due_Date__c = Date.today().addDays(1)
            ),
            new Care_Reminder__c(
                Name = 'Immunization',
                Patient__c = patient.Id,
                Reminder_Type__c = 'Immunization',
                Reminder_Status__c = 'Pending',
                Due_Date__c = Date.today().addDays(2)
            ),
            new Care_Reminder__c(
                Name = 'Routine Check-up',
                Patient__c = patient.Id,
                Reminder_Type__c = 'Routine Check-up',
                Reminder_Status__c = 'Pending',
                Due_Date__c = Date.today().addDays(3)
            )
        };

        Test.startTest();
        insert reminders;
        Test.stopTest();

        Set<Id> reminderIds = new Set<Id>();
        for (Care_Reminder__c reminder : reminders) {
            reminderIds.add(reminder.Id);
        }
        Map<Id, Care_Reminder__c> savedById = new Map<Id, Care_Reminder__c>([
            SELECT Id, Reminder_Type__c, Reminder_Status__c, Due_Date__c
            FROM Care_Reminder__c
            WHERE Id IN :reminderIds
        ]);
        System.assertEquals(3, savedById.size());
        for (Care_Reminder__c reminder : reminders) {
            Care_Reminder__c saved = savedById.get(reminder.Id);
            System.assertEquals('Pending', saved.Reminder_Status__c);
            System.assertEquals(reminder.Due_Date__c, saved.Due_Date__c);
            System.assertEquals(reminder.Reminder_Type__c, saved.Reminder_Type__c);
        }
    }

    @IsTest
    static void rejectsPendingReminderWithoutDueDate() {
        Patient__c patient = [SELECT Id FROM Patient__c LIMIT 1];
        Care_Reminder__c reminder = new Care_Reminder__c(
            Name = 'Missing due date',
            Patient__c = patient.Id,
            Reminder_Type__c = 'Follow-up',
            Reminder_Status__c = 'Pending'
        );

        Test.startTest();
        Database.SaveResult result = Database.insert(reminder, false);
        Test.stopTest();

        System.assertEquals(false, result.isSuccess());
        System.assert(
            result.getErrors()[0].getMessage().contains('A due date is required'),
            'The Flow should explain that Pending reminders need a due date.'
        );
    }

    @IsTest
    static void requiredFieldsRejectMissingPatientTypeOrStatus() {
        Patient__c patient = [SELECT Id FROM Patient__c LIMIT 1];
        List<Care_Reminder__c> reminders = new List<Care_Reminder__c>{
            new Care_Reminder__c(
                Name = 'Missing patient',
                Reminder_Type__c = 'Follow-up',
                Reminder_Status__c = 'Pending',
                Due_Date__c = Date.today().addDays(1)
            ),
            new Care_Reminder__c(
                Name = 'Missing type',
                Patient__c = patient.Id,
                Reminder_Status__c = 'Pending',
                Due_Date__c = Date.today().addDays(1)
            ),
            new Care_Reminder__c(
                Name = 'Missing status',
                Patient__c = patient.Id,
                Reminder_Type__c = 'Follow-up',
                Due_Date__c = Date.today().addDays(1)
            )
        };

        Test.startTest();
        Database.SaveResult[] results = Database.insert(reminders, false);
        Test.stopTest();

        System.assertEquals(3, results.size());
        for (Database.SaveResult result : results) {
            System.assertEquals(false, result.isSuccess());
        }
    }

    @IsTest
    static void doesNotResetTerminalStatuses() {
        Patient__c patient = [SELECT Id FROM Patient__c LIMIT 1];
        List<Care_Reminder__c> reminders = new List<Care_Reminder__c>{
            new Care_Reminder__c(
                Name = 'Already sent',
                Patient__c = patient.Id,
                Reminder_Type__c = 'Follow-up',
                Reminder_Status__c = 'Sent',
                Due_Date__c = Date.today()
            ),
            new Care_Reminder__c(
                Name = 'Already completed',
                Patient__c = patient.Id,
                Reminder_Type__c = 'Immunization',
                Reminder_Status__c = 'Completed',
                Due_Date__c = Date.today()
            ),
            new Care_Reminder__c(
                Name = 'Already cancelled',
                Patient__c = patient.Id,
                Reminder_Type__c = 'Routine Check-up',
                Reminder_Status__c = 'Cancelled',
                Due_Date__c = Date.today()
            )
        };

        Test.startTest();
        insert reminders;
        Test.stopTest();

        Set<Id> reminderIds = new Set<Id>();
        for (Care_Reminder__c reminder : reminders) {
            reminderIds.add(reminder.Id);
        }
        Map<Id, Care_Reminder__c> savedById = new Map<Id, Care_Reminder__c>([
            SELECT Id, Reminder_Status__c
            FROM Care_Reminder__c
            WHERE Id IN :reminderIds
        ]);
        System.assertEquals(3, savedById.size());
        for (Care_Reminder__c reminder : reminders) {
            System.assertEquals(reminder.Reminder_Status__c, savedById.get(reminder.Id).Reminder_Status__c);
        }
    }
}
