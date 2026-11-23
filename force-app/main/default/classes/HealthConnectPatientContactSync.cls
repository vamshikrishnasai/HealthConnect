public without sharing class HealthConnectPatientContactSync {
    public static void syncHealthCases(List<Health_Case__c> records) {
        Set<Id> patientIds = patientIdsFromCases(records);
        Map<Id, Id> contactByPatient = getContactByPatient(patientIds);
        for (Health_Case__c record : records) {
            record.Portal_Contact__c = contactByPatient.get(record.Patient__c);
        }
    }

    public static void syncAppointments(List<Appointment__c> records) {
        Set<Id> patientIds = patientIdsFromAppointments(records);
        Map<Id, Id> contactByPatient = getContactByPatient(patientIds);
        for (Appointment__c record : records) {
            record.Portal_Contact__c = contactByPatient.get(record.Patient__c);
        }
    }

    public static void syncCareReminders(List<Care_Reminder__c> records) {
        Set<Id> patientIds = patientIdsFromReminders(records);
        Map<Id, Id> contactByPatient = getContactByPatient(patientIds);
        for (Care_Reminder__c record : records) {
            record.Portal_Contact__c = contactByPatient.get(record.Patient__c);
        }
    }

    public static void syncImmunizations(List<Immunization__c> records) {
        Set<Id> patientIds = patientIdsFromImmunizations(records);
        Map<Id, Id> contactByPatient = getContactByPatient(patientIds);
        for (Immunization__c record : records) {
            record.Portal_Contact__c = contactByPatient.get(record.Patient__c);
        }
    }

    public static void syncChildrenForPatients(
        List<Patient__c> patients,
        Map<Id, Patient__c> oldPatients
    ) {
        Map<Id, Id> contactByPatient = new Map<Id, Id>();
        for (Patient__c patient : patients) {
            Patient__c oldPatient = oldPatients.get(patient.Id);
            if (oldPatient.Portal_Contact__c != patient.Portal_Contact__c) {
                contactByPatient.put(patient.Id, patient.Portal_Contact__c);
            }
        }
        if (contactByPatient.isEmpty()) {
            return;
        }

        Set<Id> patientIds = contactByPatient.keySet();
        List<Health_Case__c> casesToUpdate = new List<Health_Case__c>();
        List<Health_Case__c> relatedCases = (List<Health_Case__c>) Database.queryWithBinds(
            'SELECT Id, Patient__c, Portal_Contact__c FROM Health_Case__c WHERE Patient__c IN :patientIds',
            new Map<String, Object>{ 'patientIds' => patientIds },
            AccessLevel.SYSTEM_MODE
        );
        for (Health_Case__c healthCase : relatedCases) {
            Id portalContactId = contactByPatient.get(healthCase.Patient__c);
            if (healthCase.Portal_Contact__c != portalContactId) {
                healthCase.Portal_Contact__c = portalContactId;
                casesToUpdate.add(healthCase);
            }
        }
        if (!casesToUpdate.isEmpty()) {
            Database.update(casesToUpdate, true, AccessLevel.SYSTEM_MODE);
        }

        List<Appointment__c> appointmentsToUpdate = new List<Appointment__c>();
        List<Appointment__c> relatedAppointments =
            (List<Appointment__c>) Database.queryWithBinds(
                'SELECT Id, Patient__c, Portal_Contact__c FROM Appointment__c WHERE Patient__c IN :patientIds',
                new Map<String, Object>{ 'patientIds' => patientIds },
                AccessLevel.SYSTEM_MODE
            );
        for (Appointment__c appointment : relatedAppointments) {
            Id portalContactId = contactByPatient.get(appointment.Patient__c);
            if (appointment.Portal_Contact__c != portalContactId) {
                appointment.Portal_Contact__c = portalContactId;
                appointmentsToUpdate.add(appointment);
            }
        }
        if (!appointmentsToUpdate.isEmpty()) {
            Database.update(appointmentsToUpdate, true, AccessLevel.SYSTEM_MODE);
        }

        List<Care_Reminder__c> remindersToUpdate = new List<Care_Reminder__c>();
        List<Care_Reminder__c> relatedReminders =
            (List<Care_Reminder__c>) Database.queryWithBinds(
                'SELECT Id, Patient__c, Portal_Contact__c FROM Care_Reminder__c WHERE Patient__c IN :patientIds',
                new Map<String, Object>{ 'patientIds' => patientIds },
                AccessLevel.SYSTEM_MODE
            );
        for (Care_Reminder__c reminder : relatedReminders) {
            Id portalContactId = contactByPatient.get(reminder.Patient__c);
            if (reminder.Portal_Contact__c != portalContactId) {
                reminder.Portal_Contact__c = portalContactId;
                remindersToUpdate.add(reminder);
            }
        }
        if (!remindersToUpdate.isEmpty()) {
            Database.update(remindersToUpdate, true, AccessLevel.SYSTEM_MODE);
        }

        List<Immunization__c> immunizationsToUpdate = new List<Immunization__c>();
        List<Immunization__c> relatedImmunizations =
            (List<Immunization__c>) Database.queryWithBinds(
                'SELECT Id, Patient__c, Portal_Contact__c FROM Immunization__c WHERE Patient__c IN :patientIds',
                new Map<String, Object>{ 'patientIds' => patientIds },
                AccessLevel.SYSTEM_MODE
            );
        for (Immunization__c immunization : relatedImmunizations) {
            Id portalContactId = contactByPatient.get(immunization.Patient__c);
            if (immunization.Portal_Contact__c != portalContactId) {
                immunization.Portal_Contact__c = portalContactId;
                immunizationsToUpdate.add(immunization);
            }
        }
        if (!immunizationsToUpdate.isEmpty()) {
            Database.update(immunizationsToUpdate, true, AccessLevel.SYSTEM_MODE);
        }
    }

    private static Map<Id, Id> getContactByPatient(Set<Id> patientRecordIds) {
        Map<Id, Id> contactByPatient = new Map<Id, Id>();
        if (patientRecordIds.isEmpty()) {
            return contactByPatient;
        }
        List<Patient__c> patients = (List<Patient__c>) Database.queryWithBinds(
            'SELECT Id, Portal_Contact__c FROM Patient__c WHERE Id IN :patientRecordIds',
            new Map<String, Object>{ 'patientRecordIds' => patientRecordIds },
            AccessLevel.SYSTEM_MODE
        );
        for (Patient__c patient : patients) {
            contactByPatient.put(patient.Id, patient.Portal_Contact__c);
        }
        return contactByPatient;
    }

    private static Set<Id> patientIdsFromCases(List<Health_Case__c> records) {
        Set<Id> patientIds = new Set<Id>();
        for (Health_Case__c record : records) {
            if (record.Patient__c != null) {
                patientIds.add(record.Patient__c);
            }
        }
        return patientIds;
    }

    private static Set<Id> patientIdsFromAppointments(List<Appointment__c> records) {
        Set<Id> patientIds = new Set<Id>();
        for (Appointment__c record : records) {
            if (record.Patient__c != null) {
                patientIds.add(record.Patient__c);
            }
        }
        return patientIds;
    }

    private static Set<Id> patientIdsFromReminders(List<Care_Reminder__c> records) {
        Set<Id> patientIds = new Set<Id>();
        for (Care_Reminder__c record : records) {
            if (record.Patient__c != null) {
                patientIds.add(record.Patient__c);
            }
        }
        return patientIds;
    }

    private static Set<Id> patientIdsFromImmunizations(List<Immunization__c> records) {
        Set<Id> patientIds = new Set<Id>();
        for (Immunization__c record : records) {
            if (record.Patient__c != null) {
                patientIds.add(record.Patient__c);
            }
        }
        return patientIds;
    }
}
