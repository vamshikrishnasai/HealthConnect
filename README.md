<img width="509" height="432" alt="image" src="https://github.com/user-attachments/assets/8e3d5ee8-a8a6-4f58-a0ae-ac633b8b8aa0" />
HealthConnect -- Community Healthcare Outreach Platform
Project Overview
HealthConnect is a Salesforce-based community healthcare outreach
platform designed to help healthcare teams manage patient information,
coordinate medical case reviews, and support preventive care.

The platform connects four main user groups:
- Health Workers register patients, maintain patient information,
  and create health cases based on symptoms and medical history.
- Doctors review assigned cases, record medical recommendations,
  and identify patients who need follow-up care.
- Patients use a secure Salesforce Experience Cloud portal to
  access the health information and services made available to them.
- Administrators oversee healthcare activities and use reports and
  dashboards to monitor cases, appointments, immunizations, and
  outreach needs.
HealthConnect aims to reduce manual record keeping, improve coordination
between healthcare workers and doctors, and help prevent patients from
missing important vaccinations, check-ups, and follow-up visits.
Key Features
1. Patient Management
- Register and maintain patient information.
- Store contact details, date of birth, gender, address, village, and
  region.
- Maintain notification preferences and consent information.
2. Health Worker and Doctor Management
- Maintain health worker and doctor profiles.
- Record doctor specializations and associated health centres.
- Associate health workers and doctors with healthcare centres and
  regions.
3. Health Case Management
- Create digital health cases for registered patients.
- Record symptoms, symptom duration, medical history, and severity.
- Assign cases to doctors for review.
- Track case progress from submission through review, recommendations,
  follow-up, and closure.
4. Doctor Review and Recommendations
- Allow doctors to review assigned health cases.
- Record medical and medication recommendations.
- Identify cases that require another consultation or follow-up.
5. Appointment Management
- Manage initial consultations, follow-up visits, routine check-ups,
  and immunization appointments.
- Record appointment date, time, doctor, location, and status.
- Track scheduled, confirmed, completed, cancelled, and missed
  appointments.
6. Immunization Tracking
- Maintain patient vaccination records.
- Record vaccine names, dose numbers, due dates, and administration
  dates.
- Track planned, due, completed, overdue, and missed immunizations.
7. Automated Care Reminder Creation
- Use Salesforce Flow to create care reminder records for eligible
  immunizations, routine check-ups, and follow-ups.
- Associate reminders with relevant patients and healthcare records.
- Apply eligibility checks to help avoid creating reminders for
  completed or ineligible activities.
8. Reminder Monitoring
- Track reminder status and intended notification channel.
- Store delivery status, sent time, retry count, and error details
  where applicable.
- Support configured channel values such as SMS, WhatsApp, voice call,
  and Experience Cloud.
Integration note: Creating a reminder record does not, by itself,
deliver an SMS, WhatsApp message, or voice call. Actual external
notifications require a separately configured messaging or telephony
integration. The project should only be described as sending messages
once that integration has been implemented and tested.

9. Patient Self-Service Portal
- Provide a patient-facing portal using Salesforce Experience Cloud.
- Allow authenticated patients to access only the health information
  made available to their account.
- Support patient access to relevant health records, appointments,
  immunizations, and recommendations, according to the configured
  portal pages and permissions.
10. Role-Based Access and Secure Information Sharing
- Separate access for administrators, health workers, doctors, and
  patients.
- Use Salesforce permissions and record-sharing configuration to
  control access to patient and healthcare records.
- Restrict patient portal access to the records associated with the
  authenticated patient.
11. Reports and Dashboards
- Present healthcare information through Salesforce reports and
  dashboards.
- Monitor health cases, appointments, immunization status, and care
  reminders.
- Support analysis of regional outreach activity and potential gaps in
  preventive care.
Technology Stack
  Technology                         Purpose
  Salesforce Platform            Core cloud platform for the
healthcare application, data,
users, security, and automation.

  Salesforce Custom Objects and    Store patients, health workers,
Fields                           doctors, health centres, cases,
appointments, immunizations, and
care reminders.

  Salesforce Flow Builder        Automate health-case
initialization and the creation of
eligible care reminder records.

  Apex                           Server-side business logic and
controller functionality where
implemented.

  Lightning Web Components (LWC) Build custom Lightning
user-interface components and
patient dashboard experiences.

  SOQL                           Query Salesforce records for
application logic and data
display.

  Salesforce Experience Cloud    Provide the patient self-service
portal.

  Profiles, Permission Sets, and   Manage user permissions and
Sharing Configuration            record-level access.

  Salesforce Reports and           Present operational metrics and
Dashboards                       healthcare insights.

  Visual Studio Code             Development environment for
Salesforce metadata and source
code.

  Salesforce CLI                 Authenticate with the Salesforce
org, retrieve metadata, and deploy
project components.
Git and GitHub                 Version control and source-code
collaboration.
Salesforce Data Model
The project uses the following eight custom objects:
  Custom Object                      Description
  Patient__c                       Stores patient details and
notification preferences.

  Health_Worker__c                 Stores health worker details and
health-centre association.

  Doctor__c                        Stores doctor details,
specialization, and health-centre
association.

  Health_Centre__c                 Stores healthcare centre
information and regional details.

  Health_Case__c                   Stores patient symptoms, medical
history, severity, case status,
and recommendations.

  Care_Appointment__c              Stores consultation and follow-up
appointment details.

  Immunization__c                  Tracks vaccine details, doses, due
dates, and administration status.
Care_Reminder__c                 Stores reminder details, related
records, intended channel, and
tracking status.
Typical Workflow
1. A health worker registers a patient.
2. The health worker creates a health case and records the patient's
   symptoms and medical history.
3. The case is submitted and assigned to a doctor.
4. The doctor reviews the case and records recommendations.
5. An appointment or follow-up may be scheduled when required.
6. Immunization and care records are monitored for upcoming or overdue
   activities.
7. Salesforce Flow creates eligible care reminder records.
8. Patients access permitted information through the Experience Cloud
   portal.
9. Administrators use reports and dashboards to monitor healthcare
   activities and identify outreach gaps.
Project Objective
The objective of HealthConnect is to support more organized, accessible,
and proactive community healthcare by bringing patient records, medical
case management, preventive-care tracking, reminders, and healthcare
reporting together on the Salesforce platform.
Project: HealthConnect -- Outreach Programme
Platform: Salesforce
Category: Community Healthcare / Healthcare Outreach
