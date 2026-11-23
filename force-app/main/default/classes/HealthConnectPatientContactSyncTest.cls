@IsTest
private class HealthConnectPatientContactSyncTest {
    @TestSetup
    static void createHealthWorker() {
        Profile workerProfile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'HealthConnect Health Worker'
            LIMIT 1
        ];
        String uniqueValue = String.valueOf(DateTime.now().getTime());
        insert new User(
            Alias = 'hcwrk',
            Email = 'hc-worker-' + uniqueValue + '@example.test',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Health Worker',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = workerProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'hc-worker-' + uniqueValue + '@example.test'
        );
    }

    @IsTest
    static void copiesPortalContactToRelatedCareAndRefreshesWhenChanged() {
        Account account = new Account(Name = 'HealthConnect Test Account');
        insert account;
        Contact firstContact = new Contact(LastName = 'First Patient', AccountId = account.Id);
        Contact secondContact = new Contact(LastName = 'Second Patient', AccountId = account.Id);
        insert new List<Contact>{ firstContact, secondContact };

        User worker = [SELECT Id FROM User WHERE Alias = 'hcwrk' LIMIT 1];
        Patient__c patient;
        Health_Case__c healthCase;
        Appointment__c appointment;
        Care_Reminder__c reminder;
        Immunization__c immunization;

        Test.startTest();
        System.runAs(worker) {
            patient = new Patient__c(Name = 'Test Patient');
            insert patient;

            healthCase = new Health_Case__c(
                Patient__c = patient.Id,
                Case_Priority__c = 'Medium',
                Case_Status__c = 'New'
            );
            insert healthCase;
            appointment = new Appointment__c(
                Patient__c = patient.Id,
                Health_Case__c = healthCase.Id,
                Appointment_Date__c = Date.today().addDays(1),
                Appointment_Time__c = '10:00 AM',
                Appointment_Status__c = 'Scheduled'
            );
            insert appointment;
            reminder = new Care_Reminder__c(
                Name = 'Patient follow-up',
                Patient__c = patient.Id,
                Reminder_Type__c = 'Follow-up',
                Reminder_Status__c = 'Pending',
                Due_Date__c = Date.today().addDays(2)
            );
            insert reminder;
            immunization = new Immunization__c(
                Patient__c = patient.Id,
                Vaccine_Name__c = 'Test vaccine',
                Date_Administered__c = Date.today()
            );
            insert immunization;

            patient.Portal_Contact__c = firstContact.Id;
            update patient;
            patient.Portal_Contact__c = secondContact.Id;
            update patient;
        }
        Test.stopTest();

        System.runAs(worker) {
            System.assertEquals(
                secondContact.Id,
                [SELECT Portal_Contact__c FROM Health_Case__c WHERE Id = :healthCase.Id].Portal_Contact__c
            );
            System.assertEquals(
                secondContact.Id,
                [SELECT Portal_Contact__c FROM Appointment__c WHERE Id = :appointment.Id].Portal_Contact__c
            );
            System.assertEquals(
                secondContact.Id,
                [SELECT Portal_Contact__c FROM Care_Reminder__c WHERE Id = :reminder.Id].Portal_Contact__c
            );
            System.assertEquals(
                secondContact.Id,
                [SELECT Portal_Contact__c FROM Immunization__c WHERE Id = :immunization.Id].Portal_Contact__c
            );
        }
    }

    @IsTest
    static void clearsChildPortalContactsForBulkPatientUpdates() {
        Account account = new Account(Name = 'HealthConnect Bulk Test Account');
        insert account;
        Contact firstContact = new Contact(LastName = 'First Bulk Patient', AccountId = account.Id);
        Contact secondContact = new Contact(LastName = 'Second Bulk Patient', AccountId = account.Id);
        insert new List<Contact>{ firstContact, secondContact };

        User worker = [SELECT Id FROM User WHERE Alias = 'hcwrk' LIMIT 1];
        List<Patient__c> patients = new List<Patient__c>();
        List<Health_Case__c> healthCases = new List<Health_Case__c>();
        List<Appointment__c> appointments = new List<Appointment__c>();
        List<Care_Reminder__c> reminders = new List<Care_Reminder__c>();
        List<Immunization__c> immunizations = new List<Immunization__c>();

        Test.startTest();
        System.runAs(worker) {
            patients.addAll(new List<Patient__c>{
                new Patient__c(Name = 'First Bulk Patient', Portal_Contact__c = firstContact.Id),
                new Patient__c(Name = 'Second Bulk Patient', Portal_Contact__c = secondContact.Id)
            });
            insert patients;

            for (Patient__c patient : patients) {
                healthCases.add(new Health_Case__c(
                    Patient__c = patient.Id,
                    Case_Priority__c = 'Medium',
                    Case_Status__c = 'New'
                ));
            }
            insert healthCases;

            for (Integer index = 0; index < patients.size(); index++) {
                Patient__c patient = patients[index];
                Health_Case__c healthCase = healthCases[index];
                appointments.add(new Appointment__c(
                    Patient__c = patient.Id,
                    Health_Case__c = healthCase.Id,
                    Appointment_Date__c = Date.today().addDays(1),
                    Appointment_Time__c = '10:00 AM',
                    Appointment_Status__c = 'Scheduled'
                ));
                reminders.add(new Care_Reminder__c(
                    Name = 'Bulk patient follow-up',
                    Patient__c = patient.Id,
                    Reminder_Type__c = 'Follow-up',
                    Reminder_Status__c = 'Pending',
                    Due_Date__c = Date.today().addDays(2)
                ));
                immunizations.add(new Immunization__c(
                    Patient__c = patient.Id,
                    Vaccine_Name__c = 'Bulk test vaccine',
                    Date_Administered__c = Date.today()
                ));
            }
            insert appointments;
            insert reminders;
            insert immunizations;

            List<Patient__c> patientsToClear = new List<Patient__c>();
            for (Patient__c patient : patients) {
                patientsToClear.add(new Patient__c(
                    Id = patient.Id,
                    Portal_Contact__c = null
                ));
            }
            update patientsToClear;
        }
        Test.stopTest();

        Set<Id> healthCaseIds = new Set<Id>();
        Set<Id> appointmentIds = new Set<Id>();
        Set<Id> reminderIds = new Set<Id>();
        Set<Id> immunizationIds = new Set<Id>();
        for (Health_Case__c healthCase : healthCases) {
            healthCaseIds.add(healthCase.Id);
        }
        for (Appointment__c appointment : appointments) {
            appointmentIds.add(appointment.Id);
        }
        for (Care_Reminder__c reminder : reminders) {
            reminderIds.add(reminder.Id);
        }
        for (Immunization__c immunization : immunizations) {
            immunizationIds.add(immunization.Id);
        }

        List<Health_Case__c> savedCases = [
            SELECT Portal_Contact__c
            FROM Health_Case__c
            WHERE Id IN :healthCaseIds
        ];
        System.assertEquals(2, savedCases.size());
        for (Health_Case__c healthCase : savedCases) {
            System.assertEquals(null, healthCase.Portal_Contact__c);
        }
        List<Appointment__c> savedAppointments = [
            SELECT Portal_Contact__c
            FROM Appointment__c
            WHERE Id IN :appointmentIds
        ];
        System.assertEquals(2, savedAppointments.size());
        for (Appointment__c appointment : savedAppointments) {
            System.assertEquals(null, appointment.Portal_Contact__c);
        }
        List<Care_Reminder__c> savedReminders = [
            SELECT Portal_Contact__c
            FROM Care_Reminder__c
            WHERE Id IN :reminderIds
        ];
        System.assertEquals(2, savedReminders.size());
        for (Care_Reminder__c reminder : savedReminders) {
            System.assertEquals(null, reminder.Portal_Contact__c);
        }
        List<Immunization__c> savedImmunizations = [
            SELECT Portal_Contact__c
            FROM Immunization__c
            WHERE Id IN :immunizationIds
        ];
        System.assertEquals(2, savedImmunizations.size());
        for (Immunization__c immunization : savedImmunizations) {
            System.assertEquals(null, immunization.Portal_Contact__c);
        }
    }
}
