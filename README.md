# HealthConnect — Deployed Salesforce Project

## Source of truth and scope

This README documents the HealthConnect configuration verified in the connected Salesforce org, `HealthConnectOrg`, on **26 October 2026**. It describes the deployed state, not the local Salesforce DX source tree or earlier project guides. Deployed metadata can establish that components are configured or active, but it does not by itself prove every end-to-end workflow, effective user permission, or email delivery.

No patient data is included in this documentation. Verify the current org state before using this as a deployment checklist because Salesforce configuration can change after the review date.

## Project overview

HealthConnect is a Salesforce care-management solution for health workers, doctors, and patients. It brings patient profiles, health cases, appointments, immunizations, and care reminders into one Salesforce org. Health workers coordinate patient and case records; doctors review cases assigned to their Salesforce User; and patients can access their own information through Experience Cloud, when their login and Contact are correctly linked to a Patient record. Salesforce Flows automate reminders and appointment steps, while Apex supports validation, Contact synchronization, provisioning, and record sharing. The same Salesforce records power internal CRM workflows and the external patient and doctor portal experiences.

## Users and responsibilities

| User/persona | Salesforce identity | Main responsibilities |
|---|---|---|
| Health worker | Internal Salesforce User | Maintain patient and care records, coordinate cases, schedule appointments, and manage reminders according to assigned permissions. |
| Doctor | Salesforce User associated with doctor access | Review assigned Health Cases and related appointments; enter clinical information subject to validation and permissions. |
| Patient | External Experience Cloud User linked to a Contact | View patient-specific portal information and update permitted profile fields. |
| Administrator | Salesforce administrator | Manage org configuration, users, permissions, Experience sites, and deployed automation. |

Exact effective capabilities depend on the user's assigned profile, permission sets, record ownership, sharing, and field-level security.

## Technology used

| Technology | How it is used |
|---|---|
| Salesforce Platform / CRM | Stores and secures standard records and HealthConnect custom objects. |
| Salesforce Experience Cloud | Hosts the patient and doctor external sites and their authenticated experiences. |
| Aura ExperienceBundle | Runtime used by deployed Aura Experience Cloud sites. |
| Lightning Web Runtime (LWR) | Runtime used by deployed LWR Digital Experiences. Aura and LWR sites can access the same Salesforce org; they are different site runtimes, not separate databases. |
| Lightning Web Components (LWC) | Provide portal UI, including the patient dashboard and profile interaction. |
| Apex | Implements portal controllers, business logic, provisioning, sharing, Contact synchronization, and appointment-conflict checks. |
| SOQL and user-mode operations | Retrieve records and enforce the running user's access for deployed portal operations. |
| Salesforce Record-Triggered, Screen, and Scheduled Flows | Automate reminder validation, case follow-up reminders, appointment creation, reminder completion, and scheduled processing. |
| Apex triggers | Run server-side logic as records are inserted, updated, or deleted, according to each trigger's configured events. |
| Validation Rules and formula fields | Enforce required data and derive immunization status. |
| Sharing Sets, Apex-managed sharing, profiles, and permission sets | Control object, field, and record access for internal and external users. |

The presence of an email action in a Flow is not evidence that an email reached a recipient's inbox.

## Data model

### Standard Salesforce objects

| Object | Responsibility in HealthConnect |
|---|---|
| `Account` | Salesforce account context used with Experience Cloud external-user setup; it is not the clinical Patient record. |
| `Contact` | Connects external portal identities to the care application. An external User is linked to a Contact, and the Patient record stores the corresponding portal Contact. |
| `User` | Represents internal staff and external logins. Doctor assignment on Health Cases and Appointments references a Salesforce User. |

Salesforce profiles, permission sets, permission-set assignments, and sharing configuration also participate in access control.

### HealthConnect custom objects

| API name | Label | Responsibility and key relationships |
|---|---|---|
| `Patient__c` | Patient | Patient profile and portal link. `Portal_Contact__c` connects the Patient to a Salesforce Contact. |
| `Doctor__c` | Doctor | Doctor directory/profile information, with Contact/User links. Case and appointment assignment uses Salesforce User fields. |
| `Health_Case__c` | Health Case | Care concern, status, priority, diagnosis, recommendation, and follow-up details. Links to a Patient and assigned doctor User. This is the HealthConnect clinical case object; it is not Salesforce's standard `Case` object. |
| `Appointment__c` | Appointment | Scheduled visit linked to a Patient, Health Case, and doctor User. |
| `Care_Reminder__c` | Care Reminder | Follow-up, immunization, or routine reminder linked to a Patient and optionally a Health Case or Appointment. |
| `Immunization__c` | Immunization | Patient vaccine and due-date information. |
| `HealthConnect_Access_Grant__c` | HealthConnect Access Grant | Supports managed record access and is protected by an Apex guard trigger. |

The deployed inventory contained **seven HealthConnect custom objects**. At a high level, Patient is the care-data hub: Health Cases, Appointments, Care Reminders, and Immunizations are associated with the relevant Patient. A portal User's Contact provides the identity link to that Patient.

## Deployed business flow

1. A health worker maintains the Patient and links the Patient to the portal Contact where applicable.
2. A Health Case is created and can be assigned to a doctor Salesforce User.
3. A user can launch the **Schedule Appointment From Case** Screen Flow from a case. The Flow gathers scheduling details and creates an Appointment associated with the case, patient, and doctor. Apex checks appointment conflicts, while trigger automation maintains portal Contact values and record sharing.
4. When a Health Case requires follow-up and has the required patient/date information, a record-triggered Flow creates or updates a Pending Care Reminder.
5. A daily scheduled Flow selects eligible Pending reminders due exactly two days ahead. It checks for a patient email, invokes its configured email action, and marks the reminder Sent. A Sent status or successful Flow path is not a delivery receipt.
6. A patient signs in to Experience Cloud. Salesforce supplies the logged-in User and Contact; the patient dashboard resolves the matching Patient and displays data only as permitted by controller and sharing access.
7. When the patient edits allowed profile details, the portal controller locates the Patient through the logged-in Contact and updates that Salesforce Patient record in user mode.

## Active deployed Flows

The following five HealthConnect Flows were confirmed Active in the org on **26 October 2026**.

| Flow | Active version | Type / entry point | Deployed purpose |
|---|---:|---|---|
| Care Reminder Processing | 3 | Before-save record-triggered Flow for a new Pending Care Reminder | Allows the supported reminder types Follow-up, Immunization, or Routine Check-up and requires a Due Date. |
| Create or Update Case Follow-up Reminder | 3 | After-save record-triggered Flow on Health Case create/update | Creates a Pending follow-up reminder or updates its existing Pending reminder when follow-up is required and the necessary patient/date information exists. It can link a matching scheduled Appointment. |
| Mark Care Reminder Complete | 1 | Screen Flow / quick action | Marks an open Pending or Sent reminder Completed. |
| Schedule Appointment From Case | 8 | Screen Flow / case action | Collects scheduling details, checks for an active appointment, creates a linked Scheduled Appointment, and provides confirmation or fault handling. The deployed Flow does not contain an email action. |
| Scheduled Care Reminder Automation | 10 | Daily scheduled Flow | Processes Pending reminders due exactly two days ahead, checks the patient's email, invokes a configured email action, and then sets the reminder status to Sent. |

## Active deployed Apex triggers

The following **11 Apex triggers** were confirmed Active in the deployed org on **26 October 2026**.

| Trigger | Main responsibility |
|---|---|
| `PatientPortalContactSync` | After Patient update, synchronizes portal Contact values to related care records. |
| `HealthCasePortalContactSync` | Maintains portal Contact information on Health Cases. |
| `HealthCaseSharing` | Maintains managed sharing for Health Cases. |
| `AppointmentConflictValidation` | Checks for appointment scheduling conflicts. |
| `AppointmentPortalContactSync` | Maintains portal Contact information on Appointments. |
| `AppointmentSharing` | Maintains managed sharing for Appointments. |
| `CareReminderPortalContactSync` | Maintains portal Contact information on Care Reminders. |
| `CareReminderSharing` | Maintains Care Reminder sharing; the deployed automation excludes doctor portal permission from its sharing behavior. |
| `HealthConnectAccessGrantGuard` | Guards managed Access Grant records against direct mutation. |
| `ImmunizationPortalContactSync` | Maintains portal Contact information on Immunizations. |
| `HealthConnectPatientPortalUserProvisioning` | After User insertion, starts patient portal provisioning. |

Trigger responsibilities above summarize the deployed trigger entry points and related automation; they are not a substitute for checking the current Apex implementation or running an end-to-end test.

## Validation rules and formula

### Active validation rules

| Rule | Object | Behavior |
|---|---|---|
| `Recommendation_Requires_Clinical_Fields` | `Health_Case__c` | Requires clinical fields, including diagnosis and doctor recommendation, before the case can move to Recommendation Provided. |
| `Follow_Up_Requires_Date` | `Health_Case__c` | Requires a follow-up date when the case status is Follow-up Required. |
| `Doctor_Cannot_Change_Patient_Or_Priority` | `Health_Case__c` | Prevents a doctor from changing the Patient or case Priority. |
| `Appointment_Requires_Scheduling_Details` | `Appointment__c` | Requires Patient, Health Case, date, and time on every save; the rule is not limited to a particular status. |

The Care Reminder Processing Flow also validates reminder type and Due Date, but that logic is Flow behavior rather than a Validation Rule.

### Deployed formula field

`Immunization__c.Current_Status__c` returns **Due** when `Next_Due_Date__c` is populated and is on or before `TODAY()`; otherwise, it returns **Completed**.

## Experience Cloud and portal data access

### Deployed sites

| Site / network | Runtime and route information | Deployed status |
|---|---|---|
| `healthconnect` / `healthconnect1` | Aura ExperienceBundle; `/s` | Live; self-registration disabled. |
| `HealthConnect Patient Portal` / `HealthConnect_Patient_Portal1` | LWR Digital Experience; route prefix `healthconnectportalvforcesite` | Live; self-registration enabled. |
| `HealthConnect Doctor Portal` | Aura Experience site | Live. |
| `HealthConnect Doctor Portal LWR` | LWR Digital Experience | Live. |

### Patient identity path

1. The authenticated external Salesforce User has a `ContactId`.
2. The patient dashboard controller matches that Contact to `Patient__c.Portal_Contact__c`.
3. The controller retrieves that Patient's Health Cases, Appointments, Care Reminders, and Immunizations, subject to its user-mode and sharing checks.
4. A Sharing Set maps the matching Contact to the Patient record and related care records, providing record-level access in addition to object and field permissions.

The patient profile update controller derives the Patient from the current user's Contact rather than trusting a Patient ID submitted by the portal. It requires exactly one matching Patient and performs the update in user mode; a successful update changes the Salesforce Patient record used by the application.

### Access model and verification caveat

- The Patient Sharing Set grants the matching Contact **Edit** access to its Patient record.
- The patient care-record Sharing Set grants the matching Contact **Read** access to Health Cases, Appointments, Care Reminders, and Immunizations.
- Object permissions, field-level security, record sharing, and Apex user-mode enforcement all matter. A Sharing Set alone does not guarantee that every displayed field is readable.
- The deployed permission-set metadata did not explicitly list field access for some fields queried by the patient dashboard, including Immunization vaccine/date, Care Reminder type/status, and Appointment Patient. Other permission assignments could provide access. Validate effective permissions with an approved external test user before relying on every portal panel.
- The presence of a Live site and deployed metadata is not evidence that an end-to-end portal login or every dashboard path was tested.

## Other Salesforce configuration

- **Record Types:** No HealthConnect record types were found in the deployed inventory reviewed.
- **Custom Metadata Types and Custom Settings:** None were found in the reviewed deployed inventory.
- **Reports and Dashboards:** No deployed HealthConnect reports or dashboards were found in the reviewed inventory.
- **Salesforce standard Case:** The HealthConnect clinical workflow uses `Health_Case__c`; do not confuse it with the standard Salesforce `Case` object.
- **Async Apex:** The deployed patient portal provisioning entry point starts provisioning after User creation. This is distinct from Flow scheduling; confirm the current Apex implementation and org runtime if documenting transaction-level details.


