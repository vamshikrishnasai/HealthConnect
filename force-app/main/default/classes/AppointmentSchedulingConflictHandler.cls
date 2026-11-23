public without sharing class AppointmentSchedulingConflictHandler {
  private static final Set<String> ACTIVE_STATUSES = new Set<String>{
    'Scheduled',
    'Rescheduled'
  };
  private static final String CONFLICT_MESSAGE = 'This doctor already has an appointment scheduled for this date and time. Choose a different time.';
  private static final String CASE_CONFLICT_MESSAGE = 'This Health Case already has an active appointment. Complete or cancel it before scheduling another appointment.';

  public static void validateNoDoctorTimeConflicts(
    List<Appointment__c> appointments
  ) {
    Set<Id> doctorIds = new Set<Id>();
    Set<Id> healthCaseIds = new Set<Id>();
    Set<Date> appointmentDates = new Set<Date>();
    Set<String> appointmentTimes = new Set<String>();
    Set<Id> updatedAppointmentIds = new Set<Id>();
    Map<String, List<Appointment__c>> requestedBySlot = new Map<String, List<Appointment__c>>();
    Map<Id, List<Appointment__c>> requestedByHealthCase = new Map<Id, List<Appointment__c>>();

    for (Appointment__c appointment : appointments) {
      if (appointment.Id != null) {
        updatedAppointmentIds.add(appointment.Id);
      }
      if (
        appointment.Health_Case__c != null &&
        ACTIVE_STATUSES.contains(appointment.Appointment_Status__c)
      ) {
        healthCaseIds.add(appointment.Health_Case__c);
        if (!requestedByHealthCase.containsKey(appointment.Health_Case__c)) {
          requestedByHealthCase.put(
            appointment.Health_Case__c,
            new List<Appointment__c>()
          );
        }
        requestedByHealthCase.get(appointment.Health_Case__c).add(appointment);
      }
      if (!isActiveAppointment(appointment)) {
        continue;
      }

      doctorIds.add(appointment.Assigned_Doctor__c);
      appointmentDates.add(appointment.Appointment_Date__c);
      appointmentTimes.add(appointment.Appointment_Time__c);
      String slotKey = buildSlotKey(
        appointment.Assigned_Doctor__c,
        appointment.Appointment_Date__c,
        appointment.Appointment_Time__c
      );
      if (!requestedBySlot.containsKey(slotKey)) {
        requestedBySlot.put(slotKey, new List<Appointment__c>());
      }
      requestedBySlot.get(slotKey).add(appointment);
    }

    if (!requestedByHealthCase.isEmpty()) {
      validateNoActiveAppointmentForHealthCase(
        healthCaseIds,
        updatedAppointmentIds,
        requestedByHealthCase
      );
    }

    if (requestedBySlot.isEmpty()) {
      return;
    }

    Set<String> occupiedSlots = new Set<String>();
    for (Appointment__c existingAppointment : [
      SELECT Id, Assigned_Doctor__c, Appointment_Date__c, Appointment_Time__c
      FROM Appointment__c
      WHERE
        Assigned_Doctor__c IN :doctorIds
        AND Appointment_Date__c IN :appointmentDates
        AND Appointment_Time__c IN :appointmentTimes
        AND Appointment_Status__c IN :ACTIVE_STATUSES
    ]) {
      if (updatedAppointmentIds.contains(existingAppointment.Id)) {
        continue;
      }
      String slotKey = buildSlotKey(
        existingAppointment.Assigned_Doctor__c,
        existingAppointment.Appointment_Date__c,
        existingAppointment.Appointment_Time__c
      );
      if (requestedBySlot.containsKey(slotKey)) {
        occupiedSlots.add(slotKey);
      }
    }

    for (String slotKey : requestedBySlot.keySet()) {
      List<Appointment__c> requestedAppointments = requestedBySlot.get(slotKey);
      if (occupiedSlots.contains(slotKey) || requestedAppointments.size() > 1) {
        for (Appointment__c appointment : requestedAppointments) {
          appointment.addError(CONFLICT_MESSAGE);
        }
      }
    }
  }

  private static void validateNoActiveAppointmentForHealthCase(
    Set<Id> healthCaseIds,
    Set<Id> updatedAppointmentIds,
    Map<Id, List<Appointment__c>> requestedByHealthCase
  ) {
    Set<Id> lockedHealthCaseIds = new Set<Id>();
    for (Health_Case__c healthCase : [
      SELECT Id
      FROM Health_Case__c
      WHERE Id IN :healthCaseIds
      FOR UPDATE
    ]) {
      lockedHealthCaseIds.add(healthCase.Id);
    }

    Set<Id> occupiedHealthCaseIds = new Set<Id>();
    for (Appointment__c existingAppointment : [
      SELECT Id, Health_Case__c
      FROM Appointment__c
      WHERE
        Health_Case__c IN :lockedHealthCaseIds
        AND Appointment_Status__c IN :ACTIVE_STATUSES
    ]) {
      if (updatedAppointmentIds.contains(existingAppointment.Id)) {
        continue;
      }
      occupiedHealthCaseIds.add(existingAppointment.Health_Case__c);
    }

    for (Id healthCaseId : requestedByHealthCase.keySet()) {
      List<Appointment__c> requestedAppointments = requestedByHealthCase.get(
        healthCaseId
      );
      if (
        occupiedHealthCaseIds.contains(healthCaseId) ||
        requestedAppointments.size() > 1
      ) {
        for (Appointment__c appointment : requestedAppointments) {
          appointment.addError(CASE_CONFLICT_MESSAGE);
        }
      }
    }
  }

  private static Boolean isActiveAppointment(Appointment__c appointment) {
    return appointment.Assigned_Doctor__c != null &&
      appointment.Appointment_Date__c != null &&
      String.isNotBlank(appointment.Appointment_Time__c) &&
      ACTIVE_STATUSES.contains(appointment.Appointment_Status__c);
  }

  private static String buildSlotKey(
    Id doctorId,
    Date appointmentDate,
    String appointmentTime
  ) {
    return String.valueOf(doctorId) +
      '|' +
      String.valueOf(appointmentDate) +
      '|' +
      appointmentTime;
  }
}
