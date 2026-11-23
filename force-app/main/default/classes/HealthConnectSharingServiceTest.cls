@IsTest
private with sharing class HealthConnectSharingServiceTest {
    @TestSetup
    static void createTestUsers() {
        Profile workerProfile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'HealthConnect Health Worker'
            LIMIT 1
        ];
        Profile doctorProfile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'HealthConnect Doctor'
            LIMIT 1
        ];
        Profile administratorProfile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'System Administrator'
            LIMIT 1
        ];
        String suffix = String.valueOf(DateTime.now().getTime()) +
            String.valueOf(Crypto.getRandomInteger()).replace('-', '');
        User worker = new User(
            Alias = 'hcwrk',
            Email = 'hc-worker-' + suffix + '@example.test',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Health Worker',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = workerProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'hc-worker-' + suffix + '@example.test'
        );
        User doctor = new User(
            Alias = 'hcdoctor',
            Email = 'hc-doctor-' + suffix + '@example.test',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Doctor',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = doctorProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'hc-doctor-' + suffix + '@example.test'
        );
        User administrator = new User(
            Alias = 'hcadm',
            Email = 'hc-admin-' + suffix + '@example.test',
            EmailEncodingKey = 'UTF-8',
            LastName = 'HealthConnect Administrator',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = administratorProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'hc-admin-' + suffix + '@example.test'
        );
        insert new List<User>{ worker, doctor, administrator };

        Map<String, PermissionSet> setsByName = new Map<String, PermissionSet>();
        for (PermissionSet permissionSet : [
            SELECT Id, Name
            FROM PermissionSet
            WHERE Name IN ('HealthConnect_Health_Worker', 'HealthConnect_Doctor')
        ]) {
            setsByName.put(permissionSet.Name, permissionSet);
        }
        System.assertEquals(2, setsByName.size(), 'Both HealthConnect permission sets must be deployed.');
        insert new List<PermissionSetAssignment>{
            new PermissionSetAssignment(AssigneeId = worker.Id, PermissionSetId = setsByName.get('HealthConnect_Health_Worker').Id),
            new PermissionSetAssignment(AssigneeId = doctor.Id, PermissionSetId = setsByName.get('HealthConnect_Doctor').Id)
        };
    }

    @IsTest
    static void sharesAssignedCareAndRemovesStaleDoctorAccess() {
        User worker = [SELECT Id FROM User WHERE Alias = 'hcwrk' LIMIT 1];
        User doctor = [SELECT Id FROM User WHERE Alias = 'hcdoctor' LIMIT 1];
        User administrator = [SELECT Id FROM User WHERE Alias = 'hcadm' LIMIT 1];

        Patient__c assignedPatient = new Patient__c();
        Patient__c unrelatedPatient = new Patient__c();
        Health_Case__c assignedCase;
        Health_Case__c unrelatedCase;
        System.runAs(worker) {
            insert new List<Patient__c>{ assignedPatient, unrelatedPatient };
            assignedCase = new Health_Case__c(
                Patient__c = assignedPatient.Id,
                Case_Priority__c = 'Medium',
                Case_Status__c = 'New',
                Assigned_Doctor__c = doctor.Id
            );
            unrelatedCase = new Health_Case__c(
                Patient__c = unrelatedPatient.Id,
                Case_Priority__c = 'Low',
                Case_Status__c = 'New'
            );
            insert new List<Health_Case__c>{ assignedCase, unrelatedCase };
            insert new Appointment__c(
                Patient__c = assignedPatient.Id,
                Health_Case__c = assignedCase.Id,
                Assigned_Doctor__c = doctor.Id,
                Appointment_Date__c = Date.today().addDays(7),
                Appointment_Time__c = '09:00 AM',
                Appointment_Status__c = 'Scheduled'
            );
            insert new Care_Reminder__c(
                Name = 'Test follow-up',
                Patient__c = assignedPatient.Id,
                Health_Case__c = assignedCase.Id,
                Reminder_Type__c = 'Follow-up',
                Reminder_Status__c = 'Pending',
                Due_Date__c = Date.today().addDays(7)
            );
        }

        Id assignedCaseId = assignedCase.Id;
        Id unrelatedCaseId = unrelatedCase.Id;
        Id assignedPatientId = assignedPatient.Id;
        Id appointmentId = [
            SELECT Id
            FROM Appointment__c
            WHERE Health_Case__c = :assignedCaseId
            LIMIT 1
        ].Id;
        Id reminderId = [
            SELECT Id
            FROM Care_Reminder__c
            WHERE Health_Case__c = :assignedCaseId
            LIMIT 1
        ].Id;
        System.assertEquals(4, [SELECT count() FROM HealthConnect_Access_Grant__c]);

        System.runAs(doctor) {
            System.assertEquals(1, [SELECT count() FROM Health_Case__c WHERE Id = :assignedCaseId]);
            System.assertEquals(0, [SELECT count() FROM Health_Case__c WHERE Id = :unrelatedCaseId]);
            System.assertEquals(1, [SELECT count() FROM Patient__c WHERE Id = :assignedPatientId]);
            System.assertEquals(1, [SELECT count() FROM Appointment__c WHERE Id = :appointmentId]);
            System.assertEquals(1, [SELECT count() FROM Care_Reminder__c WHERE Id = :reminderId]);
            Database.SaveResult diagnosisUpdate = Database.update(
                new Health_Case__c(Id = assignedCaseId, Diagnosis__c = 'Doctor review entered'),
                false,
                AccessLevel.USER_MODE
            );
            System.assert(diagnosisUpdate.isSuccess(), 'Doctors can update diagnosis on an assigned case.');
            Database.SaveResult statusUpdate = Database.update(
                new Health_Case__c(Id = assignedCaseId, Case_Status__c = 'Under Review'),
                false,
                AccessLevel.USER_MODE
            );
            System.assert(statusUpdate.isSuccess(), 'Doctors can update case status.');
            Database.SaveResult appointmentRequiredUpdate = Database.update(
                new Health_Case__c(Id = assignedCaseId, Appointment_Required__c = true),
                false,
                AccessLevel.USER_MODE
            );
            System.assert(appointmentRequiredUpdate.isSuccess(), 'Doctors can update the appointment requirement.');
            Database.SaveResult symptomsUpdate = Database.update(
                new Health_Case__c(Id = assignedCaseId, Symptoms__c = 'Unauthorized change'),
                false,
                AccessLevel.USER_MODE
            );
            System.assert(!symptomsUpdate.isSuccess(), 'Doctors cannot edit intake symptoms.');
            Database.SaveResult patientAssociationUpdate = Database.update(
                new Health_Case__c(Id = assignedCaseId, Patient__c = unrelatedPatient.Id),
                false,
                AccessLevel.USER_MODE
            );
            System.assert(!patientAssociationUpdate.isSuccess(), 'Doctors cannot reassign a case to another patient.');
            Database.SaveResult priorityUpdate = Database.update(
                new Health_Case__c(Id = assignedCaseId, Case_Priority__c = 'Urgent'),
                false,
                AccessLevel.USER_MODE
            );
            System.assert(!priorityUpdate.isSuccess(), 'Doctors cannot change the health-worker intake priority.');
            Database.SaveResult patientUpdate = Database.update(
                new Patient__c(Id = assignedPatientId, Email__c = 'blocked@example.test'),
                false,
                AccessLevel.USER_MODE
            );
            System.assert(!patientUpdate.isSuccess(), 'Doctors have read-only access to Patient records.');
        }

        System.runAs(worker) {
            Database.SaveResult intakeUpdate = Database.update(
                new Health_Case__c(Id = assignedCaseId, Symptoms__c = 'Intake updated'),
                false,
                AccessLevel.USER_MODE
            );
            System.assert(intakeUpdate.isSuccess(), 'Health workers can update intake symptoms.');
            Database.SaveResult recommendationUpdate = Database.update(
                new Health_Case__c(Id = assignedCaseId, Doctor_Recommendation__c = 'Unauthorized change'),
                false,
                AccessLevel.USER_MODE
            );
            System.assert(!recommendationUpdate.isSuccess(), 'Health workers cannot edit doctor recommendations.');
            Database.SaveResult appointmentRequiredUpdate = Database.update(
                new Health_Case__c(Id = assignedCaseId, Appointment_Required__c = false),
                false,
                AccessLevel.USER_MODE
            );
            System.assert(!appointmentRequiredUpdate.isSuccess(), 'Health workers cannot change appointment requirements.');

            HealthConnect_Access_Grant__c userModeGrant = new HealthConnect_Access_Grant__c(
                Target_Object__c = 'Health_Case__c',
                Target_Record_Id__c = String.valueOf(assignedCaseId),
                Target_User_Id__c = String.valueOf(doctor.Id),
                Access_Level__c = 'Edit',
                Grant_Key__c = 'blocked-user-created-grant'
            );
            Database.SaveResult userModeGrantResult = Database.insert(
                userModeGrant,
                false,
                AccessLevel.USER_MODE
            );
            System.assert(!userModeGrantResult.isSuccess(), 'Users must not have access to create grant records.');

            HealthConnect_Access_Grant__c systemModeGrant = new HealthConnect_Access_Grant__c(
                Target_Object__c = 'Health_Case__c',
                Target_Record_Id__c = String.valueOf(assignedCaseId),
                Target_User_Id__c = String.valueOf(doctor.Id),
                Access_Level__c = 'Edit',
                Grant_Key__c = 'blocked-system-context-grant'
            );
            Database.SaveResult systemModeGrantResult = Database.insert(
                systemModeGrant,
                false,
                AccessLevel.SYSTEM_MODE
            );
            System.assert(!systemModeGrantResult.isSuccess(), 'The access-grant trigger must block direct system-mode inserts.');
            System.assert(
                systemModeGrantResult.getErrors()[0].getMessage().contains('managed by HealthConnect automation.'),
                'The access-grant trigger should explain that records are automation-managed.'
            );

            update new Health_Case__c(Id = assignedCaseId, Assigned_Doctor__c = null);
        }

        System.runAs(doctor) {
            System.assertEquals(0, [SELECT count() FROM Health_Case__c WHERE Id = :assignedCaseId]);
            System.assertEquals(0, [SELECT count() FROM Patient__c WHERE Id = :assignedPatientId]);
            System.assertEquals(0, [SELECT count() FROM Appointment__c WHERE Id = :appointmentId]);
            System.assertEquals(0, [SELECT count() FROM Care_Reminder__c WHERE Id = :reminderId]);
        }

        System.runAs(administrator) {
            Set<Id> caseIds = new Set<Id>{ assignedCaseId, unrelatedCaseId };
            Set<Id> patientIds = new Set<Id>{ assignedPatientId, unrelatedPatient.Id };
            System.assertEquals(2, [SELECT count() FROM Health_Case__c WHERE Id IN :caseIds]);
            System.assertEquals(2, [SELECT count() FROM Patient__c WHERE Id IN :patientIds]);
            System.assertEquals(1, [SELECT count() FROM Appointment__c WHERE Id = :appointmentId]);
            System.assertEquals(1, [SELECT count() FROM Care_Reminder__c WHERE Id = :reminderId]);
            System.assertEquals(0, [SELECT count() FROM HealthConnect_Access_Grant__c]);
        }
    }
}
