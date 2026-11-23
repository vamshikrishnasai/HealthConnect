public without sharing class HealthConnectSharingService {
    private static Boolean modifyAllData;
    private static Boolean grantMutationInProgress = false;

    /** Indicates whether this service is currently updating managed access-grant records. */
    public static Boolean isGrantMutationInProgress() {
        return grantMutationInProgress;
    }

    /**
     * Updates case, patient, appointment, and reminder shares when a case is created,
     * reassigned, or moved to a different patient.
     */
    public static void syncHealthCases(
        List<Health_Case__c> newCases,
        Map<Id, Health_Case__c> oldCases
    ) {
        Set<Id> caseIds = new Set<Id>();
        Set<Id> relatedCaseIds = new Set<Id>();
        Set<Id> patientIds = new Set<Id>();

        for (Health_Case__c healthCase : newCases) {
            Health_Case__c oldCase = oldCases == null ? null : oldCases.get(healthCase.Id);
            Boolean doctorOrOwnerChanged = oldCase == null ||
                oldCase.Assigned_Doctor__c != healthCase.Assigned_Doctor__c ||
                oldCase.OwnerId != healthCase.OwnerId;
            Boolean patientChanged = oldCase == null || oldCase.Patient__c != healthCase.Patient__c;

            if (doctorOrOwnerChanged) {
                caseIds.add(healthCase.Id);
                relatedCaseIds.add(healthCase.Id);
            }
            if (doctorOrOwnerChanged || patientChanged) {
                if (healthCase.Patient__c != null) {
                    patientIds.add(healthCase.Patient__c);
                }
                if (oldCase != null && oldCase.Patient__c != null) {
                    patientIds.add(oldCase.Patient__c);
                }
            }
        }

        Map<Id, Map<Id, String>> desiredCaseShares = new Map<Id, Map<Id, String>>();
        if (!caseIds.isEmpty()) {
            for (Health_Case__c healthCase : [
                SELECT Id, Assigned_Doctor__c
                FROM Health_Case__c
                WHERE Id IN :caseIds
            ]) {
                desiredCaseShares.put(healthCase.Id, new Map<Id, String>());
                addShare(desiredCaseShares, healthCase.Id, healthCase.Assigned_Doctor__c, 'Edit');
            }
            synchronizeShares('Health_Case__Share', desiredCaseShares);
        }

        syncPatientShares(patientIds);
        syncAppointments(relatedCaseIds);
        syncReminders(relatedCaseIds);
    }

    /** Refreshes appointment access for appointments and cases affected by an appointment change. */
    public static void syncAppointmentsForRecords(List<Appointment__c> appointments, Map<Id, Appointment__c> oldAppointments) {
        Set<Id> caseIds = new Set<Id>();
        Set<Id> appointmentIds = new Set<Id>();
        for (Appointment__c appointment : appointments) {
            appointmentIds.add(appointment.Id);
            if (appointment.Health_Case__c != null) {
                caseIds.add(appointment.Health_Case__c);
            }
        }
        if (oldAppointments != null) {
            for (Appointment__c oldAppointment : oldAppointments.values()) {
                appointmentIds.add(oldAppointment.Id);
                if (oldAppointment.Health_Case__c != null) {
                    caseIds.add(oldAppointment.Health_Case__c);
                }
            }
        }
        syncAppointments(caseIds, appointmentIds);
    }

    /** Refreshes reminder access for reminders and cases affected by a reminder change. */
    public static void syncRemindersForRecords(List<Care_Reminder__c> reminders, Map<Id, Care_Reminder__c> oldReminders) {
        Set<Id> caseIds = new Set<Id>();
        Set<Id> reminderIds = new Set<Id>();
        for (Care_Reminder__c reminder : reminders) {
            reminderIds.add(reminder.Id);
            if (reminder.Health_Case__c != null) {
                caseIds.add(reminder.Health_Case__c);
            }
        }
        if (oldReminders != null) {
            for (Care_Reminder__c oldReminder : oldReminders.values()) {
                reminderIds.add(oldReminder.Id);
                if (oldReminder.Health_Case__c != null) {
                    caseIds.add(oldReminder.Health_Case__c);
                }
            }
        }
        syncReminders(caseIds, reminderIds);
    }

    /** Shares each patient's record with the owners and assigned doctors of that patient's cases. */
    private static void syncPatientShares(Set<Id> patientIds) {
        if (patientIds.isEmpty()) {
            return;
        }

        Map<Id, Id> patientOwners = new Map<Id, Id>();
        for (Patient__c patient : [
            SELECT Id, OwnerId
            FROM Patient__c
            WHERE Id IN :patientIds
        ]) {
            patientOwners.put(patient.Id, patient.OwnerId);
        }

        Map<Id, Map<Id, String>> desiredShares = new Map<Id, Map<Id, String>>();
        for (Id patientId : patientIds) {
            desiredShares.put(patientId, new Map<Id, String>());
        }
        for (Health_Case__c healthCase : [
            SELECT OwnerId, Patient__c, Assigned_Doctor__c
            FROM Health_Case__c
            WHERE Patient__c IN :patientIds
        ]) {
            Id patientOwnerId = patientOwners.get(healthCase.Patient__c);
            addShare(desiredShares, healthCase.Patient__c, healthCase.OwnerId, 'Read', patientOwnerId);
            addShare(desiredShares, healthCase.Patient__c, healthCase.Assigned_Doctor__c, 'Read', patientOwnerId);
        }

        synchronizeShares('Patient__Share', desiredShares);
    }

    /** Refreshes appointment shares for all appointments linked to the supplied cases. */
    private static void syncAppointments(Set<Id> caseIds) {
        syncAppointments(caseIds, new Set<Id>());
    }

    /** Shares appointments with the related case owner and assigned doctor, removing stale managed shares. */
    private static void syncAppointments(Set<Id> caseIds, Set<Id> appointmentIds) {
        if (caseIds.isEmpty() && appointmentIds.isEmpty()) {
            return;
        }

        Map<Id, Health_Case__c> casesById = new Map<Id, Health_Case__c>([
            SELECT Id, OwnerId, Assigned_Doctor__c
            FROM Health_Case__c
            WHERE Id IN :caseIds
        ]);
        Map<Id, Map<Id, String>> desiredShares = new Map<Id, Map<Id, String>>();
        for (Appointment__c appointment : [
            SELECT Id, OwnerId, Health_Case__c
            FROM Appointment__c
            WHERE Health_Case__c IN :caseIds OR Id IN :appointmentIds
        ]) {
            desiredShares.put(appointment.Id, new Map<Id, String>());
            Health_Case__c healthCase = casesById.get(appointment.Health_Case__c);
            if (healthCase != null) {
                addShare(desiredShares, appointment.Id, healthCase.OwnerId, 'Edit', appointment.OwnerId);
                addShare(desiredShares, appointment.Id, healthCase.Assigned_Doctor__c, 'Edit', appointment.OwnerId);
            }
        }

        synchronizeShares('Appointment__Share', desiredShares);
    }

    /** Refreshes reminder shares for all reminders linked to the supplied cases. */
    private static void syncReminders(Set<Id> caseIds) {
        syncReminders(caseIds, new Set<Id>());
    }

    /** Shares reminders with the related case owner and assigned doctor, removing stale managed shares. */
    private static void syncReminders(Set<Id> caseIds, Set<Id> reminderIds) {
        if (caseIds.isEmpty() && reminderIds.isEmpty()) {
            return;
        }

        Map<Id, Health_Case__c> casesById = new Map<Id, Health_Case__c>([
            SELECT Id, OwnerId, Assigned_Doctor__c
            FROM Health_Case__c
            WHERE Id IN :caseIds
        ]);
        Map<Id, Map<Id, String>> desiredShares = new Map<Id, Map<Id, String>>();
        for (Care_Reminder__c reminder : [
            SELECT Id, OwnerId, Health_Case__c
            FROM Care_Reminder__c
            WHERE Health_Case__c IN :caseIds OR Id IN :reminderIds
        ]) {
            desiredShares.put(reminder.Id, new Map<Id, String>());
            Health_Case__c healthCase = casesById.get(reminder.Health_Case__c);
            if (healthCase != null) {
                addShare(desiredShares, reminder.Id, healthCase.OwnerId, 'Edit', reminder.OwnerId);
                addShare(desiredShares, reminder.Id, healthCase.Assigned_Doctor__c, 'Read', reminder.OwnerId);
            }
        }

        synchronizeShares('Care_Reminder__Share', desiredShares);
    }

    /** Adds a requested share unless the target user is the record owner. */
    private static void addShare(
        Map<Id, Map<Id, String>> desiredShares,
        Id recordId,
        Id userId,
        String accessLevel
    ) {
        addShare(desiredShares, recordId, userId, accessLevel, null);
    }

    /** Adds a requested share, skipping invalid or owner entries and keeping the strongest access level. */
    private static void addShare(
        Map<Id, Map<Id, String>> desiredShares,
        Id recordId,
        Id userId,
        String accessLevel,
        Id recordOwnerId
    ) {
        if (recordId == null || userId == null || userId == recordOwnerId) {
            return;
        }
        Map<Id, String> sharesByUser = desiredShares.get(recordId);
        if (sharesByUser == null) {
            sharesByUser = new Map<Id, String>();
            desiredShares.put(recordId, sharesByUser);
        }
        if (!sharesByUser.containsKey(userId) || accessRank(accessLevel) > accessRank(sharesByUser.get(userId))) {
            sharesByUser.put(userId, accessLevel);
        }
    }

    /** Returns a numeric rank so Edit access can be compared with Read access. */
    private static Integer accessRank(String accessLevel) {
        return accessLevel == 'Edit' ? 2 : 1;
    }

    /**
     * Makes actual manual shares match the requested shares and tracks changes so
     * managed grants can later be updated or safely removed.
     */
    private static void synchronizeShares(String shareObjectName, Map<Id, Map<Id, String>> desiredShares) {
        if (desiredShares.isEmpty()) {
            return;
        }

        Set<Id> parentIds = desiredShares.keySet();
        String parentObjectName = shareObjectName.replace('__Share', '__c');
        Set<String> parentIdsAsText = new Set<String>();
        for (Id parentId : parentIds) {
            parentIdsAsText.add(String.valueOf(parentId));
        }

        Map<Id, Id> ownersByRecord = new Map<Id, Id>();
        String ownerQuery = 'SELECT Id, OwnerId FROM ' + parentObjectName + ' WHERE Id IN :parentIds';
        for (SObject parentRecord : Database.query(ownerQuery)) {
            ownersByRecord.put((Id) parentRecord.get('Id'), (Id) parentRecord.get('OwnerId'));
        }

        String queryText =
            'SELECT Id, ParentId, UserOrGroupId, AccessLevel FROM ' + shareObjectName +
            ' WHERE ParentId IN :parentIds AND RowCause = \'Manual\'';
        List<SObject> existingShares = Database.query(queryText);
        Map<String, SObject> existingByKey = new Map<String, SObject>();
        for (SObject existingShare : existingShares) {
            existingByKey.put(
                shareKey(parentObjectName, (Id) existingShare.get('ParentId'), (Id) existingShare.get('UserOrGroupId')),
                existingShare
            );
        }

        Map<String, HealthConnect_Access_Grant__c> trackedByKey = new Map<String, HealthConnect_Access_Grant__c>();
        String grantQuery =
            'SELECT Id, Grant_Key__c, Target_Record_Id__c, Target_User_Id__c, Previous_Access_Level__c ' +
            'FROM HealthConnect_Access_Grant__c WHERE Target_Object__c = :targetObject ' +
            'AND Target_Record_Id__c IN :targetIds';
        List<HealthConnect_Access_Grant__c> trackedGrants =
            (List<HealthConnect_Access_Grant__c>) Database.queryWithBinds(
                grantQuery,
                new Map<String, Object>{
                    'targetObject' => parentObjectName,
                    'targetIds' => parentIdsAsText
                },
                AccessLevel.SYSTEM_MODE
            );
        for (HealthConnect_Access_Grant__c grant : trackedGrants) {
            trackedByKey.put(grant.Grant_Key__c, grant);
        }

        List<SObject> sharesToInsert = new List<SObject>();
        List<SObject> sharesToUpdate = new List<SObject>();
        List<SObject> sharesToDelete = new List<SObject>();
        List<HealthConnect_Access_Grant__c> grantsToInsert = new List<HealthConnect_Access_Grant__c>();
        List<HealthConnect_Access_Grant__c> grantsToUpdate = new List<HealthConnect_Access_Grant__c>();
        List<HealthConnect_Access_Grant__c> grantsToDelete = new List<HealthConnect_Access_Grant__c>();
        Set<String> desiredGrantKeys = new Set<String>();

        for (Id parentId : desiredShares.keySet()) {
            Map<Id, String> desiredByUser = desiredShares.get(parentId);
            for (Id userId : desiredByUser.keySet()) {
                String key = shareKey(parentObjectName, parentId, userId);
                String accessLevel = desiredByUser.get(userId);
                SObject existingShare = existingByKey.get(key);
                HealthConnect_Access_Grant__c trackedGrant = trackedByKey.get(key);
                if (existingShare == null) {
                    requireShareManager(parentId, ownersByRecord);
                    sharesToInsert.add(newShare(shareObjectName, parentId, userId, accessLevel));
                    desiredGrantKeys.add(key);
                    if (trackedGrant == null) {
                        grantsToInsert.add(newGrant(parentObjectName, parentId, userId, accessLevel, null, key));
                    } else {
                        trackedGrant.Access_Level__c = accessLevel;
                        grantsToUpdate.add(trackedGrant);
                    }
                } else if (trackedGrant != null) {
                    desiredGrantKeys.add(key);
                    existingByKey.remove(key);
                    if ((String) existingShare.get('AccessLevel') != accessLevel) {
                        requireShareManager(parentId, ownersByRecord);
                        existingShare.put('AccessLevel', accessLevel);
                        sharesToUpdate.add(existingShare);
                        trackedGrant.Access_Level__c = accessLevel;
                        grantsToUpdate.add(trackedGrant);
                    }
                } else if (accessRank((String) existingShare.get('AccessLevel')) < accessRank(accessLevel)) {
                    requireShareManager(parentId, ownersByRecord);
                    String previousAccessLevel = (String) existingShare.get('AccessLevel');
                    existingShare.put('AccessLevel', accessLevel);
                    sharesToUpdate.add(existingShare);
                    grantsToInsert.add(newGrant(
                        parentObjectName,
                        parentId,
                        userId,
                        accessLevel,
                        previousAccessLevel,
                        key
                    ));
                } else {
                    existingByKey.remove(key);
                }
            }
        }

        for (String staleKey : trackedByKey.keySet()) {
            if (desiredGrantKeys.contains(staleKey)) {
                continue;
            }
            HealthConnect_Access_Grant__c staleGrant = trackedByKey.get(staleKey);
            SObject existingShare = existingByKey.get(staleKey);
            if (existingShare != null) {
                Id parentId = (Id) staleGrant.Target_Record_Id__c;
                requireShareManager(parentId, ownersByRecord);
                if (String.isBlank(staleGrant.Previous_Access_Level__c)) {
                    sharesToDelete.add(existingShare);
                } else {
                    existingShare.put('AccessLevel', staleGrant.Previous_Access_Level__c);
                    sharesToUpdate.add(existingShare);
                }
            }
            grantsToDelete.add(staleGrant);
            existingByKey.remove(staleKey);
        }

        if (!sharesToDelete.isEmpty()) {
            delete sharesToDelete;
        }
        if (!sharesToUpdate.isEmpty()) {
            update sharesToUpdate;
        }
        if (!sharesToInsert.isEmpty()) {
            insertShares(shareObjectName, sharesToInsert);
        }
        if (!grantsToDelete.isEmpty() || !grantsToUpdate.isEmpty() || !grantsToInsert.isEmpty()) {
            grantMutationInProgress = true;
            try {
                if (!grantsToDelete.isEmpty()) {
                    Database.delete(grantsToDelete, true, AccessLevel.SYSTEM_MODE);
                }
                if (!grantsToUpdate.isEmpty()) {
                    Database.update(grantsToUpdate, true, AccessLevel.SYSTEM_MODE);
                }
                if (!grantsToInsert.isEmpty()) {
                    Database.insert(grantsToInsert, true, AccessLevel.SYSTEM_MODE);
                }
            } finally {
                grantMutationInProgress = false;
            }
        }
    }

    /** Creates an access-grant record that tracks a share managed by this service. */
    private static HealthConnect_Access_Grant__c newGrant(
        String parentObjectName,
        Id parentId,
        Id userId,
        String accessLevel,
        String previousAccessLevel,
        String grantKey
    ) {
        return new HealthConnect_Access_Grant__c(
            Target_Object__c = parentObjectName,
            Target_Record_Id__c = String.valueOf(parentId),
            Target_User_Id__c = String.valueOf(userId),
            Access_Level__c = accessLevel,
            Previous_Access_Level__c = previousAccessLevel,
            Grant_Key__c = grantKey
        );
    }

    /** Builds a share record with its target record, user, and access level. */
    private static SObject newShare(String shareObjectName, Id parentId, Id userId, String accessLevel) {
        SObject shareRecord = Schema.getGlobalDescribe().get(shareObjectName).newSObject();
        shareRecord.put('ParentId', parentId);
        shareRecord.put('UserOrGroupId', userId);
        shareRecord.put('AccessLevel', accessLevel);
        return shareRecord;
    }

    /** Ensures only the record owner or a user with Modify All Data can change its care-team shares. */
    private static void requireShareManager(Id parentId, Map<Id, Id> ownersByRecord) {
        if (ownersByRecord.get(parentId) != UserInfo.getUserId() && !currentUserHasModifyAllData()) {
            throw new IllegalArgumentException(
                'Only the record owner or a System Administrator can grant or revoke HealthConnect care-team access. ' +
                'Ask the record owner or an administrator to perform this change.'
            );
        }
    }

    /** Checks and caches whether the current user has Modify All Data through a profile or permission set. */
    private static Boolean currentUserHasModifyAllData() {
        if (modifyAllData == null) {
            List<PermissionSet> profilePermissions = [
                SELECT Id
                FROM PermissionSet
                WHERE ProfileId = :UserInfo.getProfileId()
                    AND PermissionsModifyAllData = true
                LIMIT 1
            ];
            if (!profilePermissions.isEmpty()) {
                modifyAllData = true;
                return modifyAllData;
            }

            Set<Id> assignedPermissionSetIds = new Set<Id>();
            for (PermissionSetAssignment assignment : [
                SELECT PermissionSetId
                FROM PermissionSetAssignment
                WHERE AssigneeId = :UserInfo.getUserId()
            ]) {
                assignedPermissionSetIds.add(assignment.PermissionSetId);
            }
            modifyAllData = ![
                SELECT Id
                FROM PermissionSet
                WHERE Id IN :assignedPermissionSetIds
                    AND PermissionsModifyAllData = true
                LIMIT 1
            ].isEmpty();
        }
        return modifyAllData;
    }

    /** Builds a unique key for a record-and-user share pair. */
    private static String shareKey(String parentObjectName, Id parentId, Id userId) {
        return parentObjectName + ':' + String.valueOf(parentId) + ':' + String.valueOf(userId);
    }

    /** Inserts share records using the correct Salesforce share type and manual row cause. */
    private static void insertShares(String shareObjectName, List<SObject> sharesToInsert) {
        if (shareObjectName == 'Health_Case__Share') {
            List<Health_Case__Share> typedShares = new List<Health_Case__Share>();
            for (SObject share : sharesToInsert) {
                typedShares.add(new Health_Case__Share(
                    ParentId = (Id) share.get('ParentId'),
                    UserOrGroupId = (Id) share.get('UserOrGroupId'),
                    AccessLevel = (String) share.get('AccessLevel'),
                    RowCause = Schema.Health_Case__Share.RowCause.Manual
                ));
            }
            insert typedShares;
        } else if (shareObjectName == 'Patient__Share') {
            List<Patient__Share> typedShares = new List<Patient__Share>();
            for (SObject share : sharesToInsert) {
                typedShares.add(new Patient__Share(
                    ParentId = (Id) share.get('ParentId'),
                    UserOrGroupId = (Id) share.get('UserOrGroupId'),
                    AccessLevel = (String) share.get('AccessLevel'),
                    RowCause = Schema.Patient__Share.RowCause.Manual
                ));
            }
            insert typedShares;
        } else if (shareObjectName == 'Appointment__Share') {
            List<Appointment__Share> typedShares = new List<Appointment__Share>();
            for (SObject share : sharesToInsert) {
                typedShares.add(new Appointment__Share(
                    ParentId = (Id) share.get('ParentId'),
                    UserOrGroupId = (Id) share.get('UserOrGroupId'),
                    AccessLevel = (String) share.get('AccessLevel'),
                    RowCause = Schema.Appointment__Share.RowCause.Manual
                ));
            }
            insert typedShares;
        } else if (shareObjectName == 'Care_Reminder__Share') {
            List<Care_Reminder__Share> typedShares = new List<Care_Reminder__Share>();
            for (SObject share : sharesToInsert) {
                typedShares.add(new Care_Reminder__Share(
                    ParentId = (Id) share.get('ParentId'),
                    UserOrGroupId = (Id) share.get('UserOrGroupId'),
                    AccessLevel = (String) share.get('AccessLevel'),
                    RowCause = Schema.Care_Reminder__Share.RowCause.Manual
                ));
            }
            insert typedShares;
        } else {
            throw new IllegalArgumentException('Unsupported HealthConnect share object: ' + shareObjectName);
        }
    }

}
