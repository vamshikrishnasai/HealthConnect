# HealthConnect: implementation guide

This guide describes the Salesforce source found in this repository. A metadata
file describes intended source configuration; it does **not** prove that the
same version is deployed, active, or configured in any particular Salesforce
org.

## How to read the status labels

- **Verified** — directly evidenced by repository source.
- **Partially Verified** — the code supports the behavior, but only for some
  paths or with an important limitation.
- **Needs Org Verification** — depends on deployed metadata, org settings,
  data, assigned users, licenses, or runtime behavior.
- **Not Implemented** — the repository contains no implementation for the
  described behavior.

## 1. Project overview

**Purpose — Verified.** HealthConnect is a Salesforce care-coordination app.
Health workers register patient records and cases; a doctor can review assigned
cases; appointments and reminders can be managed; and an authenticated
Experience Cloud patient can see a read-only dashboard of their own profile,
appointments, reminders, and immunizations. The source does not establish that
this is a clinical-record system suitable for production or regulated use.

**Architecture — Verified.** Salesforce custom objects hold the data; profiles,
permission sets, private sharing, a sharing set, Apex triggers, and manual Apex
shares control access; record-triggered and scheduled Flows automate follow-up
and email; an Apex controller and Lightning Web Component (LWC) provide the
portal dashboard.

**Technologies — Verified.** Salesforce DX source format, Salesforce metadata
XML, Apex, Lightning Web Components (JavaScript/HTML/CSS), Experience Cloud
metadata, Salesforce Flow, and Jest-based LWC tests. Project source API version
is `67.0` in `sfdx-project.json`; the four Flow files declare API version
`68.0`. Treat that version difference as a deployment compatibility check, not
proof of a failure.

**Repository map — Verified.**

| Location | What it contains |
|---|---|
| `force-app/main/default/objects/` | Seven custom objects, fields, list views, and validation rules. |
| `force-app/main/default/flows/` | Four active-in-source Flow definitions. |
| `force-app/main/default/classes/`, `triggers/` | Three application Apex classes, their tests, and nine triggers. |
| `force-app/main/default/lwc/` | Patient dashboard and portal welcome components; dashboard Jest test. |
| `force-app/main/default/profiles/`, `permissionsets/` | Three custom profiles and three permission sets. |
| `force-app/main/default/sharingSets/` | Patient portal sharing set. |
| `force-app/main/default/networks/`, `sites/`, `experiences/`, `digitalExperiences/` | Experience Cloud site/network/page/theme source. |
| `force-app/main/default/layouts/`, `tabs/`, `applications/`, `quickActions/` | Lightning app navigation and record UI configuration. |
| `force-app/main/default/staticresources/` | Logo, symbol, and portal style resources. |
| `config/project-scratch-def.json` | Developer Edition scratch-org definition. |
| `scripts/` | One sample Apex script and one SOQL example; no deployment automation found. |
| `.sfdx/` | Generated Salesforce CLI typings/index artifacts, not application metadata. |

The repository root `README.md` is the generic Salesforce DX starter guide,
not project-specific setup instructions. **Verified.**

### Implemented feature summary

- Custom patient, doctor, health-case, appointment, reminder, immunization, and
  access-grant data structures. **Verified.**
- Private-by-default sharing for all seven custom objects in their object
  metadata. **Verified in source; Needs Org Verification at runtime.**
- Doctor assignment through a lookup to the Salesforce `User` object, not the
  custom `Doctor__c` object. **Verified.**
- Case-to-appointment screen Flow; follow-up reminder upsert-like Flow;
  scheduled pending-reminder email Flow. **Verified in source.**
- Patient portal dashboard showing the linked patient's profile, immunizations,
  pending/sent reminders, and scheduled/rescheduled appointments. **Verified in
  source.**
- Portal registration/self-service account creation is disabled in the
  `HealthConnect Patient Portal.network-meta.xml` source (`selfRegistration`
  false). Manual user/contact provisioning is therefore expected. **Verified in
  source; Needs Org Verification in the live site.**
- No reporting packages, integrations, clinical decision logic, or automated
  doctor-directory synchronization were found. **Not Implemented in inspected
  source.**

## 2. Objects and relationships

All custom-field types and picklist values below come from
`force-app/main/default/objects/<Object>/fields/*.field-meta.xml`. Standard
fields such as `Id`, `OwnerId`, `CreatedDate`, and the system `Name` field are
not repeated in every row. All object relationships in this schema are
**lookups**; no master-detail field was found. **Verified.**

### Relationship map

```text
Contact (standard) <- Patient__c.Portal_Contact__c
                         |
                         +-- Patient__c (parent for all care records)
                               |-- Health_Case__c.Patient__c [required]
                               |       |-- Assigned_Doctor__c -> User (standard)
                               |       |-- Appointment__c.Health_Case__c
                               |       `-- Care_Reminder__c.Health_Case__c
                               |-- Appointment__c.Patient__c [required]
                               |       |-- Assigned_Doctor__c -> User (standard)
                               |       `-- Health_Case__c -> Health_Case__c
                               |-- Care_Reminder__c.Patient__c [required]
                               |       |-- Health_Case__c -> Health_Case__c
                               |       `-- Appointment__c -> Appointment__c
                               `-- Immunization__c.Patient__c [required]
                                       `-- Administered_By__c -> User (standard)

Patient__c, Health_Case__c, Appointment__c, Care_Reminder__c, and
Immunization__c each also have Portal_Contact__c -> Contact.
```

The `Portal_Contact__c` on each child is a denormalized copy of the parent
patient's Contact link. Triggers maintain that copy so the Experience Cloud
sharing set can match a logged-in user's Contact to their own care records.
**Verified.**

### Custom object catalog

| Object / label | Name field | Important fields and exact types | Relationships |
|---|---|---|---|
| `Patient__c` / Patient | `Name` (Text) | `Address__c` TextArea; `Blood_Group__c` Picklist (`A+`, `A-`, `B+`, `B-`, `AB+`, `AB-`, `O+`, `O-`, `Unknown`); `Date_of_Birth__c` Date; `District__c` Text; `Email__c` Email; `Gender__c` Picklist (`Male`, `Female`, `Other`, `Prefer not to say`, `Unknown`); `Patient_Status__c` Picklist (`Active`, `Inactive`); `Phone_Number__c` Phone; `State__c` Text; `Village__c` Text. | `Portal_Contact__c` Lookup(Contact), optional. **Source:** `objects/Patient__c/Patient__c.object-meta.xml`; each field has a same-API-name `.field-meta.xml` in `objects/Patient__c/fields/`. |
| `Doctor__c` / Doctor | `Name` (Text) | `Availability_Status__c` Picklist (`Available`, `Unavailable`); `District__c` Text; `Email__c` Email; `Healthcare_Facility__c` Text; `Phone_Number__c` Phone; `Specialization__c` Picklist (`General Physician`, `Pediatrician`, `Cardiologist`, `Dermatologist`, `Other`). | No lookup to `User`, Patient, or another custom object is defined. **Source:** `objects/Doctor__c/Doctor__c.object-meta.xml`; fields are in `objects/Doctor__c/fields/`. |
| `Health_Case__c` / Health Case | `Name` AutoNumber (`HC-{0000}`) | `Appointment_Required__c` Checkbox; `Case_Priority__c` Picklist (`Low`, `Medium`, `High`, `Urgent`); `Case_Status__c` Picklist (`New`, `Under Review`, `Recommendation Provided`, `Follow-up Required`, `Closed`); `Diagnosis__c` Text; `Doctor_Recommendation__c` LongTextArea; `Follow_up_Date__c` Date; `Symptom_Duration_Days__c` Number; `Symptoms__c` LongTextArea. | `Patient__c` required Lookup(Patient); `Assigned_Doctor__c` optional Lookup(User); `Portal_Contact__c` optional Lookup(Contact). **Source:** `objects/Health_Case__c/Health_Case__c.object-meta.xml`; fields are in `objects/Health_Case__c/fields/`. |
| `Appointment__c` / Appointment | AutoNumber (see `objects/Appointment__c/Appointment__c.object-meta.xml`) | `Appointment_Date__c` Date; `Appointment_Notes__c` LongTextArea; `Appointment_Status__c` Picklist (`Scheduled`, `Completed`, `Cancelled`, `Rescheduled`); `Appointment_Time__c` Picklist (`09:00 AM`, `10:00 AM`, `11:00 AM`, `02:00 PM`, `03:00 PM`, `04:00 PM`). | `Patient__c` required Lookup(Patient); `Health_Case__c` optional Lookup(Health Case); `Assigned_Doctor__c` optional Lookup(User); `Portal_Contact__c` optional Lookup(Contact). **Fields:** `objects/Appointment__c/fields/`. |
| `Care_Reminder__c` / Care Reminder | `Name` (Text) | `Reminder_Notes__c` LongTextArea; `Reminder_Status__c` required Picklist (`Pending`, `Sent`, `Completed`, `Cancelled`); `Reminder_Type__c` required Picklist (`Immunization`, `Routine Check-up`, `Follow-up`); `Due_Date__c` Date. | `Patient__c` required Lookup(Patient); `Health_Case__c` optional Lookup(Health Case); `Appointment__c` optional Lookup(Appointment); `Portal_Contact__c` optional Lookup(Contact). **Source:** `objects/Care_Reminder__c/Care_Reminder__c.object-meta.xml`; fields are in `objects/Care_Reminder__c/fields/`. |
| `Immunization__c` / Immunization | AutoNumber (see `objects/Immunization__c/Immunization__c.object-meta.xml`) | `Administered_By__c` Lookup(User); `Date_Administered__c` required Date; `Dose__c` Text; `Next_Due_Date__c` Date; `Vaccine_Name__c` required Text. | `Patient__c` required Lookup(Patient); `Portal_Contact__c` optional Lookup(Contact). **Fields:** `objects/Immunization__c/fields/`. |
| `HealthConnect_Access_Grant__c` / HealthConnect Access Grant | AutoNumber | `Access_Level__c` required Picklist (`Read`, `Edit`); `Grant_Key__c` required Text; `Previous_Access_Level__c` Picklist (`Read`, `Edit`); `Target_Object__c` required Text; `Target_Record_Id__c` required Text; `Target_User_Id__c` required Text. | No actual lookup fields: the target object, record, and user IDs are stored as text. **Source:** `objects/HealthConnect_Access_Grant__c/HealthConnect_Access_Grant__c.object-meta.xml`; fields are in `objects/HealthConnect_Access_Grant__c/fields/`. |

`Appointment__c.Assigned_Doctor__c` and
`Health_Case__c.Assigned_Doctor__c` both point to `User`. The `Doctor__c`
records are therefore a separate, unlinked directory in the current schema;
their availability, specialty, district, and facility do not drive either
assignment lookup. **Verified.**

`Account`, `Contact`, `User`, `Profile`, `PermissionSet`, and
`PermissionSetAssignment` are standard Salesforce objects referenced in source:
Contacts are associated with Accounts in Apex tests, Contacts link portal users
to patients, Users are assigned doctors/record actors, and the sharing service
checks profile/permission-set Modify All Data. Salesforce-generated share
objects (`Health_Case__Share`, `Patient__Share`, `Appointment__Share`, and
`Care_Reminder__Share`) are also used by Apex. No metadata redefining these
standard/system objects is in this project. **Verified.**

## 3. Users and security

### Source-declared record sharing

- Every custom object declares `sharingModel=Private` and
  `externalSharingModel=Private` in its `*.object-meta.xml`. **Verified in
  source; Needs Org Verification after deployment.**
- No `SharingRules` metadata folder or role hierarchy definition was found.
  **Not Implemented in this repository.** The live org may have additional
  sharing rules, teams, groups, or hierarchy configuration.
- `HealthConnect_Patient_Portal` (`sharingSets/HealthConnect_Patient_Portal.sharingSet-meta.xml`)
  grants **Read** access for the signed-in user's `Contact` to matching
  `Portal_Contact__c` on Patient, Health Case, Appointment, Care Reminder, and
  Immunization. It lists both `HealthConnect Patient Community User` and
  `Customer Community Plus Login User`. **Verified in source; Needs Org
  Verification that Salesforce accepts/activates the mapping for the assigned
  license/profile.**
- `HealthConnectSharingService` creates managed manual shares on
  `Health_Case__Share`, `Patient__Share`, `Appointment__Share`, and
  `Care_Reminder__Share`. It does not create Immunization shares. **Verified.**
- These source settings do not establish the current org-wide defaults,
  deployments, role hierarchy, group memberships, ownership, or effective
  access. **Needs Org Verification** in Setup (Sharing Settings, Object
  Settings, Sharing Hierarchy, and record-level sharing).

### Profiles and permission sets

Profiles are in `force-app/main/default/profiles/`; permission sets are in
`force-app/main/default/permissionsets/`. Object permissions in the table are
for the listed custom objects; `R`, `C`, `E`, and `D` mean Read, Create, Edit,
and Delete. Where not shown, Create/Delete are false in the source definitions.

| Principal source | Source-declared object access | Notable field/class/Flow access |
|---|---|---|
| `HealthConnect Health Worker` profile (`profiles/HealthConnect Health Worker.profile-meta.xml`) + `HealthConnect_Health_Worker` (`permissionsets/HealthConnect_Health_Worker.permissionset-meta.xml`) | Patient, Health Case, Appointment, Care Reminder, Immunization: Read/Create/Edit. Doctor: Read only. | Worker profile can edit patient demographics, case intake, assignment, appointment, reminder, and immunization fields. Access-grant object permissions are not granted by these files. |
| `HealthConnect Doctor` profile (`profiles/HealthConnect Doctor.profile-meta.xml`) + `HealthConnect_Doctor` (`permissionsets/HealthConnect_Doctor.permissionset-meta.xml`) | Patient, Care Reminder, Doctor, Immunization: Read only. Health Case: Read/Edit. Appointment: Read/Create/Edit. | Doctors can edit case `Diagnosis__c`, `Doctor_Recommendation__c`, `Follow_up_Date__c`, and `Appointment_Required__c`; `Symptoms__c`, symptom duration, case doctor, and appointment doctor are read-only in the profile. The profile grants `Schedule_Appointment_From_Case` Flow access. |
| `HealthConnect Patient Community User` profile (`profiles/HealthConnect Patient Community User.profile-meta.xml`) + `HealthConnect_Patient_Portal_Access` (`permissionsets/HealthConnect_Patient_Portal_Access.permissionset-meta.xml`) | Patient, Health Case, Appointment, Care Reminder, Immunization: Read only; no Create/Edit/Delete, View All, or Modify All. | Both grant `HealthConnectPatientDashboardController`. Portal field access is read-only and includes the dashboard fields plus Contact-link fields. Permission set license is `Customer Community Plus Login`. |

The source permission files do not guarantee which profile/permission set is
assigned to any real user. Assignment, user license, community membership,
permission-set license compatibility, and effective field access all require
**Needs Org Verification**.

### How the Apex shares work

When a Health Case is created or its owner/assigned User changes, the
`HealthCaseSharing` trigger calls `HealthConnectSharingService.syncHealthCases`.
The service requests:

1. Edit access to the Health Case for its assigned doctor User.
2. Read access to the Patient for the owner and assigned doctor of each case
   for that patient.
3. Edit access to linked Appointments for the Health Case owner and assigned
   doctor.
4. Read access to linked Care Reminders for the Health Case owner and assigned
   doctor.

The service reconciles desired shares with manual (`RowCause=Manual`) shares,
tracks managed grants in `HealthConnect_Access_Grant__c`, and removes/restores
managed access when assignments change. It requires the current user to own the
target record or have `Modify All Data` before making certain share changes;
otherwise it throws an explicit `IllegalArgumentException`. See
`force-app/main/default/classes/HealthConnectSharingService.cls` and
`force-app/main/default/triggers/HealthConnectAccessGrantGuard.trigger`.
**Verified.**

**Operational consequence — Partially Verified:** a worker who is allowed to
edit a record by object permission but is not its owner or an admin may be
unable to change its doctor/ownership if the trigger needs to create or revoke
shares. Check the error text and current record owner before treating the
assignment as a lookup problem.

`HealthConnectAccessGrantGuard` blocks direct insert/update/delete of grant
records unless `HealthConnectSharingService` has set its internal mutation
flag. **Verified in source.** The guard is not a substitute for verifying
effective object permissions or installed trigger status in the live org.

### Experience Cloud identity and access

The expected identity chain is:

```text
Experience Cloud User.ContactId
     = Patient__c.Portal_Contact__c
     -> matching Patient__c.Id
     -> child records' Patient__c and copied Portal_Contact__c
```

The dashboard controller reads the current User's `ContactId`, finds exactly
one matching Patient, and rejects a missing Contact, zero matching patients,
or multiple matching patients. Portal Contact copy fields on child records
are maintained by before-save triggers and by the patient Contact-change
trigger. **Verified in source.** The actual user's Contact and Patient links
must be checked in the org.

## 4. Complete Flow inventory

Flow names, process types, start rules, and statuses below are from
`force-app/main/default/flows/*.flow-meta.xml`. All four source files contain
`<status>Active</status>`; this means **active in the retrieved source only**.
Whether a version is active in the target org is **Needs Org Verification** in
Setup > Flows. None of the inspected Flow files defines explicit fault
connectors or a dedicated error-handling path. **Verified.**

### 4.1 `Care_Reminder_Processing`

**Metadata:** `flows/Care_Reminder_Processing.flow-meta.xml`  
**Type / start:** Record-triggered, Auto-Launched Flow; `Care_Reminder__c`,
after save, on **create only** when `Reminder_Status__c = Pending`.  
**Purpose:** Classifies a newly inserted pending reminder by type.

**Execution path:**

1. Start filter selects newly created Pending Care Reminders.
2. `Check_Reminder_Type` checks `Reminder_Type__c`.
3. `Follow-up` -> `Update_Follow_up_Reminder` writes status `Pending` to the
   triggering record.
4. `Immunization` -> `Update_Immunization_Reminder` writes status `Pending`.
5. `Routine Check-up` follows the decision's default connector and does
   nothing.

**Records changed:** The same Care Reminder is updated only on the first two
branches; the assigned value is the same Pending value used by the entry
condition. No email action exists. **Verified.**

**Error handling / test:** No explicit fault route. Create one Pending reminder
for each supported type and inspect the Flow interview and record history;
verify the routine branch leaves the record unchanged. The current metadata
does not define a Flow test. **Needs Org Verification** for runtime execution.

### 4.2 `Create or Update Case Follow-up Reminder`

**Metadata:** `flows/Create_or_Update_Case_Follow_Up_Reminder.flow-meta.xml`  
**API label:** `Create or Update Case Follow-up Reminder`  
**Type / start:** Record-triggered, Auto-Launched Flow; Health Case, after save,
on create and update when status is `Follow-up Required`, Follow-up Date is
not null, and Patient is not null. `doesRequireRecordChangedToMeetCriteria`
is false, so qualifying updates can run even if the record was already
qualifying.  
**Purpose:** Keep one pending follow-up reminder associated with a Health Case
and a matching scheduled appointment.

**Execution path:**

1. `Get Matching Appointment`: first Appointment matching this Health Case,
   same Patient, Appointment Date equal to the case Follow-up Date, and status
   `Scheduled`.
2. `Get Existing Follow-up Reminder`: first Care Reminder matching this case
   and type `Follow-up`.
3. `Check Existing Reminder`:
   - If none was found, go to `Create Follow-up Reminder`.
   - If one exists, go to `Check Reminder Status`.
4. `Check Reminder Status`:
   - Pending -> `Update Pending Follow-up Reminder` changes due date, patient,
     and appointment lookup.
   - Any other status -> default branch preserves it.
5. `Create Follow-up Reminder` sets Name to the formula
   `"Follow-up - " & $Record.Name`, Patient, case, matching Appointment
   (possibly blank), type `Follow-up`, due date, status `Pending`, and notes
   equal to the generated name.

**Records changed:** One newly inserted Care Reminder if no existing matching
reminder; otherwise only an existing Pending reminder. Sent, Completed, and
Cancelled reminders are deliberately not reset. No email action exists here.
**Verified.**

**Error handling / test:** No explicit fault connector. Test a new qualifying
case; update its follow-up date; link a matching scheduled appointment; then
repeat with an existing Pending reminder and with Sent/Completed/Cancelled
reminders. Also test an unrelated case update while it already qualifies,
because the start condition does not require newly meeting the criteria.
Inspect Flow errors and duplicate reminders in the org. **Needs Org
Verification** for behavior against existing data.

**Limitation — Partially Verified:** both lookups use first-record-only with no
sort/uniqueness constraint. Duplicate matching appointments/reminders can make
the selected row unpredictable, and the Flow does not clean up duplicate
follow-up reminders.

### 4.3 `Schedule Appointment From Case`

**Metadata:** `flows/Schedule_Appointment_From_Case.flow-meta.xml`; launched
through `quickActions/Health_Case__c.Schedule_Appointment.quickAction-meta.xml`.  
**Type / start:** Screen Flow (`processType=Flow`) with input String variable
`recordId`; source status Active.  
**Purpose:** Let a user schedule an Appointment from a Health Case record.

**Execution path:**

1. `Get Health Case` looks up Health Case by input `recordId`.
2. `Enter Appointment Details` asks for required date, required time dropdown,
   and optional notes. Choices are 09:00 AM, 10:00 AM, 11:00 AM, 02:00 PM,
   03:00 PM, and 04:00 PM.
3. `Create Appointment` creates an Appointment with Patient and Assigned
   Doctor copied from the case, the case lookup, entered date/time/notes, and
   status `Scheduled`.
4. `Appointment Scheduled` displays the confirmation text.

**Records changed:** Creates one Appointment. Appointment's before-save
trigger copies Portal Contact from its Patient; its after-save sharing trigger
tries to share to the related case owner/assigned doctor. **Verified.**

**Error handling / test:** No explicit not-found branch for an invalid
`recordId`, no custom fault screen, and no date-in-the-past constraint. From a
Health Case record, use the `Schedule Appointment` quick action; test with and
without an assigned doctor, valid/invalid dates, and a missing/invalid
`recordId`. Check the Flow interview, validation errors, and Appointment
sharing. **Needs Org Verification.**

### 4.4 `Scheduled Care Reminder Automation`

**Metadata:** `flows/Scheduled_Care_Reminder_Automation.flow-meta.xml`  
**Type / start:** Scheduled-triggered Auto-Launched Flow for
`Care_Reminder__c` where status is `Pending`; daily schedule starting
`2026-10-13` at `15:00:00.000Z`.  
**Purpose:** Send a generic email for due reminders with a patient email, then
mark them Sent.

**Execution path:**

1. Select Pending reminders on the daily schedule.
2. `Check Reminder Due Date` compares `Due_Date__c <= $Flow.CurrentDate`
   (the `Current_Date` formula).
3. `Get Patient Record` looks up the Patient through `$Record.Patient__c`.
4. `Check Patient Email` routes a nonblank `Patient__c.Email__c` to
   `Send Patient Care Reminder`.
5. `Send Patient Care Reminder` uses the `emailSimple` action, subject
   `Care reminder`, a generic instruction body, the Patient custom object's
   email field, and `DefaultWorkflowUser` sender.
6. On the email action's normal connector, `Mark Due Reminder` updates the
   triggering Care Reminder status to `Sent`.
7. Not-due reminders and reminders with a blank patient email follow default
   paths; there is no explicit update on those paths.

**Records changed:** A reminder is marked Sent only after the email action
success path. **Verified.** The source does not prove that Salesforce can
deliver email or that a schedule is currently installed.

**Error handling / test:** No explicit action fault connector or failed-email
state. Create a Pending reminder with a past/today due date and populated
`Patient__c.Email__c`; check Flow interview, email logs, and status. Repeat with
a future date and blank patient email. Verify Setup > Process Automation
Settings, Flow schedule, org email deliverability, sender configuration, and
recipient address. **Needs Org Verification.**

**Delivery note — Verified source behavior:** a blank email is never changed
out of Pending, so the scheduled flow selects it again on each run. If the
email action errors, the normal path to mark Sent is not reached; confirm the
actual failure behavior in Flow error emails/interviews.

## 5. Apex: classes and triggers

### Apex classes

| Class | What it does and what invokes it |
|---|---|
| `HealthConnectPatientContactSync` (`classes/HealthConnectPatientContactSync.cls`) | `without sharing` helper called by the five Portal Contact sync triggers. It gets the Patient's `Portal_Contact__c` in system mode and copies it to new/updated Health Cases, Appointments, Care Reminders, and Immunizations. When a Patient's Contact changes, it finds existing child records, updates their Contact copies in system mode, and only writes rows where the Contact differs. It does not create/delete care records. |
| `HealthConnectSharingService` (`classes/HealthConnectSharingService.cls`) | `without sharing` service invoked by Health Case, Appointment, and Reminder after-save triggers. It derives desired manual shares, creates/updates/removes them, and tracks managed share pairs in `HealthConnect_Access_Grant__c`. It also checks record ownership/Modify All Data before share changes and uses a static mutation guard for grant-record DML. It does not share Immunizations. |
| `HealthConnectPatientDashboardController` (`classes/HealthConnectPatientDashboardController.cls`) | `with sharing`, `@AuraEnabled(cacheable=true)` Apex endpoint used by `healthConnectPatientDashboard`. It obtains the current User.ContactId and requires exactly one matching Patient. It uses `WITH USER_MODE` for Patient, Immunization, Care Reminder, and Appointment queries; caps each care-record list at 50; filters reminders to Pending/Sent and appointments to Scheduled/Rescheduled. It returns no Health Case data. Missing/multiple patient links raise `AuraHandledException`. |

Tests in source: `HealthConnectPatientContactSyncTest.cls` covers Contact copy
and parent Contact changes; `HealthConnectSharingServiceTest.cls` tests
assigned-doctor shares, stale-share removal, and access restrictions;
`HealthConnectPatientDashboardTest.cls` tests returning only linked-patient
records and rejecting a Contact with no Patient. LWC Jest coverage is in
`lwc/healthConnectPatientDashboard/__tests__/healthConnectPatientDashboard.test.js`.
**Verified.** These files are test evidence, not a record of passing Apex or
Jest runs in the current org/workstation.

### Triggers (all nine)

| Trigger | Events and called logic |
|---|---|
| `PatientPortalContactSync` (`triggers/PatientPortalContactSync.trigger`) | Patient after update -> `syncChildrenForPatients`; propagates Patient Contact changes to existing care records. |
| `HealthCasePortalContactSync` (`triggers/HealthCasePortalContactSync.trigger`) | Health Case before insert/update -> copies the Patient's Contact to `Portal_Contact__c`. |
| `AppointmentPortalContactSync` (`triggers/AppointmentPortalContactSync.trigger`) | Appointment before insert/update -> same Contact-copy behavior. |
| `CareReminderPortalContactSync` (`triggers/CareReminderPortalContactSync.trigger`) | Care Reminder before insert/update -> same Contact-copy behavior. |
| `ImmunizationPortalContactSync` (`triggers/ImmunizationPortalContactSync.trigger`) | Immunization before insert/update -> same Contact-copy behavior. |
| `HealthCaseSharing` (`triggers/HealthCaseSharing.trigger`) | Health Case after insert/update -> reconcile Health Case, Patient, linked Appointment, and Reminder shares. |
| `AppointmentSharing` (`triggers/AppointmentSharing.trigger`) | Appointment after insert/update -> reconcile related Appointment shares. |
| `CareReminderSharing` (`triggers/CareReminderSharing.trigger`) | Care Reminder after insert/update -> reconcile related Reminder shares. |
| `HealthConnectAccessGrantGuard` (`triggers/HealthConnectAccessGrantGuard.trigger`) | Access Grant before insert/update/delete -> blocks changes unless the sharing service's internal guard is set. |

**Flow/Apex interaction — Verified:** the screen Flow creates an Appointment,
which invokes its Contact-copy and sharing triggers. The case follow-up Flow
creates/updates a Care Reminder, invoking that object's Contact-copy and
sharing triggers. The scheduled Flow updates reminder status, invoking the
Reminder after-update sharing trigger. Updating the Patient's portal Contact
invokes a bulk child sync; there is no custom Apex call from the dashboard
LWC other than the Apex controller.

## 6. Validation rules and formulas

All four validation rules are marked active in the source. Their current
activation in an org needs **Needs Org Verification**.

| Rule / file | Actual formula | Plain-English effect and example |
|---|---|---|
| `Appointment_Requires_Scheduling_Details` — `objects/Appointment__c/validationRules/Appointment_Requires_Scheduling_Details.validationRule-meta.xml` | `OR(ISBLANK(Patient__c), ISBLANK(Health_Case__c), ISBLANK(Appointment_Date__c), ISBLANK(TEXT(Appointment_Time__c)))` | Rejects an Appointment without Patient, Health Case, date, or time. Example: date and time filled but no Health Case -> error. Note: the Flow copies a case relationship, but other creation paths must supply it too. |
| `Doctor_Cannot_Change_Patient_Or_Priority` — `objects/Health_Case__c/validationRules/Doctor_Cannot_Change_Patient_Or_Priority.validationRule-meta.xml` | `AND($Profile.Name = "HealthConnect Doctor", OR(ISCHANGED(Patient__c), ISCHANGED(Case_Priority__c)))` | Users whose profile name matches exactly cannot change a case's Patient or priority. Example: doctor changes Medium to Urgent -> rejected. A profile renamed in the org may no longer match. |
| `Follow_Up_Requires_Date` — `objects/Health_Case__c/validationRules/Follow_Up_Requires_Date.validationRule-meta.xml` | `AND(ISPICKVAL(Case_Status__c, "Follow-up Required"), ISBLANK(Follow_up_Date__c))` | Rejects status Follow-up Required without a date. Example: set status with blank date -> rejected. |
| `Recommendation_Requires_Clinical_Fields` — `objects/Health_Case__c/validationRules/Recommendation_Requires_Clinical_Fields.validationRule-meta.xml` | `AND(ISPICKVAL(Case_Status__c, "Recommendation Provided"), OR(ISBLANK(Diagnosis__c), ISBLANK(Doctor_Recommendation__c)))` | Rejects Recommendation Provided unless both Diagnosis and Doctor Recommendation have content. |

No custom formula fields were found in the seven custom objects. The Flows
define two formulas: `Follow_Up_Reminder_Name` is
`"Follow-up - " & $Record.Name`; `Current_Date` is `$Flow.CurrentDate`.
**Verified.**

## 7. LWC and Experience Cloud

### Components and page placement

- **`healthConnectPatientDashboard`** (`lwc/healthConnectPatientDashboard/healthConnectPatientDashboard.js`,
  `healthConnectPatientDashboard.html`, and
  `healthConnectPatientDashboard.js-meta.xml`; metadata label
  `HealthConnect Patient Dashboard`):
  fetches `HealthConnectPatientDashboardController.getDashboard()`, presents
  loading/error/guest states, and renders profile and care summaries. The Home
  Experience page source
  (`digitalExperiences/site/HealthConnect_Patient_Portal1/sfdc_cms__view/home/content.json`)
  includes `c:healthConnectPatientDashboard`. **Verified.**
- **`healthConnectPortalWelcome`** (`lwc/healthConnectPortalWelcome/healthConnectPortalWelcome.js`,
  `healthConnectPortalWelcome.html`, and
  `healthConnectPortalWelcome.js-meta.xml`; metadata label
  `HealthConnect Portal Welcome`):
  static branded welcome copy and logo. The component bundle targets Experience
  Cloud pages, but no placement of this component in the inspected page JSON
  was established. Its use in the live page is **Needs Org Verification**.
- `HealthConnectPatientDashboardController` is the only data retrieval layer
  found for the dashboard; it enforces current-user Contact linkage and uses
  USER_MODE SOQL. The LWC itself never supplies a patient ID. **Verified.**

The dashboard shows the signed-in patient's name, date of birth, blood group,
status, phone, immunizations, Pending/Sent reminders, and Scheduled/Rescheduled
appointments. It does not show the Health Case list. **Verified.**

### Portal metadata and access caveats

The project contains both `networks/HealthConnect Patient Portal.network-meta.xml`
and `networks/healthconnect.network-meta.xml`. The first says status `Live`,
site `HealthConnect_Patient_Portal`, and references the
`HealthConnect_Patient_Portal1` bundle. The second says `UnderConstruction`,
site `healthconnect`, and references a different Experience bundle. Separate
site/experience files also exist. **Verified source conflict/parallel configs;
Needs Org Verification** to identify the actual active site and which metadata
is intended for deployment.

`sites/healthconnect.site-meta.xml` declares the site active and authorization
required; `networks/HealthConnect Patient Portal.network-meta.xml` sets
self-registration false and includes the patient profiles as members. These
files are not proof that the live site is active, published, correctly
licensed, or reachable. **Needs Org Verification.**

Patient access depends on all of the following being correct at once:

1. Active Experience Cloud User with the correct profile/license and site
   membership.
2. User.ContactId points to the intended Contact.
3. Exactly one Patient has `Portal_Contact__c` equal to that Contact.
4. Child care records point to the intended Patient and have synchronized
   `Portal_Contact__c`.
5. The portal profile/permission set grants required object and field read
   access, and the sharing set is active.

## 8. End-to-end workflows

### Patient registration and portal account linking

1. A health worker creates `Patient__c`, entering the patient's identifying
   information. (Profile allows create; field metadata defines Contact lookup.)
2. A Contact is created/identified and assigned to
   `Patient__c.Portal_Contact__c`.
3. Since source self-registration is disabled, an administrator/worker must
   provision the Experience user, license, profile, and site membership, then
   make its ContactId match the Patient's Contact. The repository has no
   automation to create this user. **Partially Verified**; manual org setup is
   **Needs Org Verification**.
4. The Patient after-update trigger synchronizes Portal Contact to existing
   Health Cases, Appointments, Care Reminders, and Immunizations.
5. The sharing set grants matching Contact-based read access; the LWC calls
   Apex, which independently verifies one matching Patient and queries only
   that Patient's records.

### Health Case, doctor assignment, and access

1. Worker creates Health Case with required Patient, priority, and status.
2. `HealthCasePortalContactSync` copies the Patient Contact.
3. `HealthCaseSharing` invokes the sharing service; the case's assigned doctor
   lookup is a Salesforce User, not `Doctor__c`.
4. The service grants the assigned User Edit access to the Health Case and
   Read access to the Patient; the case owner receives the Patient share when
   not already the owner. Managed shares are tracked in
   `HealthConnect_Access_Grant__c`.
5. Related Appointments are shared with the case owner and assigned doctor
   (Edit); related Care Reminders with the owner (Edit) and doctor (Read).
6. Doctors can edit permitted clinical recommendation/status fields under
   their FLS, but the validation rule prevents changes to Patient or priority.

All steps are supported by source metadata/code. Actual record visibility
requires checking deployed shares and permissions in the org. **Needs Org
Verification** for effective access.

### Appointment scheduling

1. From a Health Case, user launches the `Schedule Appointment` quick action.
2. Flow loads case and asks for date/time/optional notes.
3. Flow inserts an Appointment with Patient, case, and assigned User copied
   from the case and status Scheduled.
4. Before-save trigger copies the Patient's Portal Contact; after-save sharing
   trigger grants access based on the related Health Case owner and assigned
   doctor.
5. Validation requires Patient, Health Case, date, and time.

### Care Reminder creation and email

1. When a Health Case is Follow-up Required with a nonblank follow-up date and
   Patient, the case Flow finds an Appointment scheduled for that exact date.
2. It creates a Pending Follow-up reminder or updates the first existing
   Pending follow-up reminder. A non-pending reminder is left unchanged.
3. Care Reminder triggers copy Portal Contact and reconcile care-team shares.
4. Daily scheduled automation selects Pending reminders whose due date has
   arrived.
5. It looks up the Patient custom email field; with a nonblank email it sends a
   generic message and marks the reminder Sent on the successful path.

Immunization and routine check-up reminders can be manually created using
fields/picklists, but the inspected source has no automation to derive those
reminders from immunization dates or routine visits. **Not Implemented in the
inspected source.**

## 9. Troubleshooting

### Doctors missing from the Assigned Doctor lookup

**Verified source facts:** `Health_Case__c.Assigned_Doctor__c` is a Lookup(User);
the custom `Doctor__c` object is not linked to User; its records do not populate
the lookup. No lookup filter is declared on the field.

Check in this order:

1. Confirm you are selecting an active, valid Salesforce User, not a
   `Doctor__c` record.
2. Confirm the intended doctor has a Salesforce User record with the
   `HealthConnect Doctor` profile and eligible license.
3. Check the User's active status, user visibility, lookup search behavior,
   and any org-specific lookup filters or restrictions in Setup.
4. Confirm deployed field metadata, object/field access, and that the doctor
   profile/permission set was actually assigned.

The source has no automated Doctor-to-User matching, no lookup filter, and no
directory-based assignment logic. **Needs Org Verification** for a specific
missing User.

### Assigned doctors cannot see Health Cases

1. Confirm the case's `Assigned_Doctor__c` is the exact Salesforce User ID of
   the signed-in doctor.
2. Confirm the doctor has Health Case Read/Edit object permission, relevant
   field access, the intended profile, and the Doctor permission set.
3. Inspect the case's `Health_Case__Share` entries, row cause, grantee, and
   access level. Check the corresponding `HealthConnect_Access_Grant__c`.
4. Confirm deployed `HealthCaseSharing` trigger is active and error-free.
5. If assignment was changed by a non-owner, inspect Flow/debug logs for the
   explicit "Only the record owner or a System Administrator..." error. The
   service requires a record owner or a user with Modify All Data for managed
   share changes.
6. Verify actual OWD and any org sharing configuration.

Also check whether the case is merely visible in the doctor list view; record
sharing and object permission are separate. **Needs Org Verification.**

### Appointment access problems

1. Confirm Appointment has the correct `Patient__c` and
   `Health_Case__c` values, and that the case itself has the correct owner and
   assigned doctor.
2. The sharing service derives Appointment shares from the related Health
   Case; it does **not** use `Appointment__c.Assigned_Doctor__c` to select
   recipients. If that appointment-only assignment differs from the parent
   case, it does not produce a separate doctor share. **Verified source
   limitation.**
3. Check `Appointment__Share`, the service grant row, after-save trigger
   execution, and FLS/object permission.
4. Appointment validation blocks saves without Patient, case, date, and time.
   Ensure date/time picklist values match metadata exactly.
5. For patients, check the Contact copy, sharing set mapping, and read-only
   permission set. For doctors, a private OWD means object Read alone does not
   grant record access.

### Reminder emails not sent

1. Check that reminder status is Pending, due date is today/past, and
   `Patient__c` is populated.
2. Check the **Patient__c.Email__c** value; the Flow does not use Contact.Email.
   Blank email leaves the reminder Pending and silently follows the default
   branch.
3. Confirm the scheduled Flow's active version and next scheduled run in Setup.
   The source schedule starts `2026-10-13` at `15:00Z`; deployed scheduling must
   be checked independently.
4. Check Flow error emails/interviews for failures in `emailSimple` or the
   subsequent status update.
5. Verify org email deliverability, sender/user validity, quotas, and
   recipient deliverability.
6. Confirm status is marked Sent only on the normal email action path; a failed
   action does not route to a configured recovery element.

## 10. Deployment and testing

### Configuration to verify before deploying

- Use a Salesforce org with API support compatible with project API `67.0` and
  Flow metadata API `68.0`; resolve any CLI/deployment API mismatch. **Needs
  Org Verification.**
- Ensure Experience Cloud and the needed Customer Community Plus Login
  licenses are available. Provision users/Contacts manually because source
  self-registration is disabled.
- Review the two network definitions and choose the intended community/site;
  the source has Live and UnderConstruction network configurations.
- Confirm org OWD remains Private (or review implications if different), site
  membership, Contact-based sharing set, profiles, permission sets, and
  FLS.
- Configure/verify org email deliverability and authorized sender. Do not
  assume the network sender metadata is accepted or verified in a target org.
- Deploy objects/fields before dependent Flows, Apex, triggers, permission
  sets, sharing sets, and Experience metadata. Activate only the intended
  Flow versions and publish the intended Experience site.
- Check for existing duplicate patients/reminders, manually created shares,
  required User records, and any org-specific metadata omitted from this
  repository.

There is no project-specific deploy script or package manifest beyond the
standard Salesforce DX `sfdx-project.json`; no deployment was performed for
this guide. **Verified.**

### Tests present and recommended

**Present in source:**

- `HealthConnectPatientContactSyncTest`: propagation of Patient Contact to
  children and update when the Patient Contact changes.
- `HealthConnectSharingServiceTest`: assigned-case visibility, patient,
  appointment, reminder access, access removal, doctor update restrictions,
  and guarding access-grant DML.
- `HealthConnectPatientDashboardTest`: only linked patient's data is returned
  and unlinked Contacts are rejected.
- `healthConnectPatientDashboard.test.js`: dashboard success and error UI
  states.

**Coverage gaps / recommended checks:**

- Add Flow tests for each of the four Flows, including branch outcomes,
  duplicate records, missing email, and fault cases.
- Test schedule behavior and email delivery in a sandbox with email logging
  and a controlled recipient; do not infer delivery from the `Sent` status
  alone.
- Add tests for invalid `recordId`, no assigned doctor, Contact link changes
  when multiple child records exist, empty appointment lookup, and
  non-owner assignment errors.
- Test a patient Experience user end-to-end with actual license, ContactId,
  sharing set, USER_MODE queries, and a second patient's records to prove
  isolation.
- Test appointment doctor mismatch (parent Health Case doctor vs appointment
  doctor) and Immunization visibility for doctors.
- Run Apex tests and LWC Jest tests in the appropriate environments; check
  Flow error emails/interviews, Apex debug logs, and Experience Cloud login
  logs.

No dependency installation or test run was performed as part of this
documentation-only request. **Verified.**

## 11. Issues, gaps, and improvement priorities

| Finding | Status | Evidence and impact |
|---|---|---|
| Doctor directory is disconnected from assignment lookup. | **Verified** | `Doctor__c` has no User lookup; both Assigned Doctor fields target `User`; no lookup filter or sync is present. A `Doctor__c` row cannot be chosen in the User lookup. Decide whether User is the intended directory or add an explicit model/mapping in a future code change. |
| Two competing Experience network configurations exist. | **Verified** | `HealthConnect Patient Portal.network-meta.xml` says Live and references `HealthConnect_Patient_Portal`; `healthconnect.network-meta.xml` says UnderConstruction and references `healthconnect`. Risk: deployment could publish/update the unintended Experience. Reconcile after checking Setup. |
| A blank patient email leaves reminder Pending indefinitely. | **Verified** | Scheduled Flow has no email-missing update/action path; the record remains eligible each day. Add an operationally visible skipped/error state or a report/process after product decision. |
| Follow-up Flow can select arbitrary duplicates. | **Partially Verified** | First-record-only queries have no sort and no unique constraint; no cleanup is present. Duplicate appointments/reminders can produce inconsistent linkage. |
| Appointment sharing ignores its own Assigned Doctor field. | **Verified** | `syncAppointments` uses parent case owner/doctor only. An appointment-specific User who differs from the case doctor does not get a share through this service. Align assignment model or explicitly share the appointment assignee. |
| No Apex sharing implementation for Immunization. | **Verified** | `HealthConnectSharingService` supports four share objects, not `Immunization__Share`; doctor profile has Immunization Read, but private record sharing may still prevent access. Verify intended doctor access and actual OWD. |
| Share-manager restriction can block assignment changes. | **Verified** | Service throws unless current user owns the target or has Modify All Data when it must create/revoke shares. This can surprise non-owner workers despite their object Edit permission. Consider a deliberate, least-privilege admin/automation model. |
| Scheduled email lacks explicit fault handling and blank-email handling. | **Verified** | No Flow fault connector; no status or notification on missing email. Operational visibility and retry behavior need improvement. |
| LWC welcome component may be unused. | **Partially Verified** | Bundle exists and is exposed, but page JSON inspected places dashboard on Home; placement for `healthConnectPortalWelcome` was not found. Check Experience Builder before removing or assuming it renders. |
| Follow-up Flow reruns on all qualifying case updates. | **Verified** | `doesRequireRecordChangedToMeetCriteria=false`. It may do unnecessary lookups for unrelated edits; evaluate trigger conditions after confirming intended behavior. |
| Flow automation has no dedicated Flow test metadata in repository. | **Verified** | No Flow tests were found; Apex tests do not directly prove Flow branches, scheduled execution, or successful email delivery. |
| Live-org security and site state are not knowable from source. | **Needs Org Verification** | OWD files, profiles, sharing set, networks, and Flow statuses are repository declarations only. Inspect Setup and test as each user type before relying on access boundaries. |
| No validation enforcing appointment's doctor equals the related case's doctor. | **Not Implemented** | The appointment Flow copies the case doctor, but the Appointment validation rule checks only Patient, case, date, and time. Other creation/update paths can diverge. |
| No automation creates portal Contacts/Users or links accounts. | **Not Implemented** | No registration provisioning flow/Apex was found; portal Contact/Patient/User setup is manual. |
| No automated immunization reminder creation from Next Due Date. | **Not Implemented** | Immunization data model and reminder types exist, but no Flow creates an Immunization Reminder from immunization records. |

## Learning roadmap

1. Start with the seven object definitions and fields; sketch the Patient as the
   parent hub and distinguish Contact/User lookups from the disconnected
   `Doctor__c` directory.
2. Read the Profiles, Permission Sets, and Sharing Set. Explain the difference
   between object permission, field permission, and record sharing.
3. Trace `HealthCaseSharing.trigger` into `HealthConnectSharingService`, then
   the Contact-sync triggers into `HealthConnectPatientContactSync`.
4. Follow the four Flows in this order: case appointment action, follow-up
   reminder creation, reminder processing, daily email. Recreate each branch
   with sample records in a sandbox.
5. Trace the portal from Home page JSON -> dashboard LWC -> Apex controller ->
   User.ContactId -> Patient.Portal_Contact__c -> child records.
6. Read the four validation formulas and explain which business mistakes each
   blocks.
7. In a sandbox, verify live site/network, Flow activation/scheduling, sharing,
   and email. Run Apex/Jest tests and add Flow tests before presenting
   production-readiness claims.
8. Practice an interview explanation: “HealthConnect uses private custom
   objects; Patient is the care-record hub; Flows handle scheduling/follow-up
   and reminders; Apex synchronizes portal Contact access and manages
   care-team shares; the portal uses a Contact-scoped sharing set and
   USER_MODE dashboard query.”

## Inspection scope and remaining unknowns

**Inspected:** repository structure and project/package configuration; all
seven custom-object field definitions and object sharing declarations; all
four Flow definitions; all three application Apex classes, nine triggers, and
three Apex test classes; profile/permission-set/share-set metadata; both
network definitions, site/Experience metadata and Home page placement; both
LWC bundles and dashboard Jest test; validation rules; quick action; app,
scratch-org, scripts, and package manifest.

**Not verified:** live-org deployments, currently active Flow versions,
Experience publication/site URL, actual OWD/sharing-rule additions, effective
user/license/permission assignments, production data quality, scheduled job
status, email deliverability, Apex test results, and runtime behavior. The
conflicting network metadata and other Setup-dependent points above must be
resolved in Salesforce Setup before treating this guide as a description of
the live org.
