Id caseId = [SELECT Id FROM Health_Case__c LIMIT 1].Id;
Savepoint sp = Database.setSavepoint();
insert new Health_Case__Share(
    ParentId = caseId,
    UserOrGroupId = '005gK00008SK8ErQAL',
    AccessLevel = 'Edit',
    RowCause = Schema.Health_Case__Share.RowCause.Assigned_Doctor__c
);
Database.rollback(sp);
