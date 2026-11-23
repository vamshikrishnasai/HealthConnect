@IsTest
private class HealthConnectPortalLoginControllerTest {
  @IsTest
  static void rejectsBlankUsernameOrPassword() {
    System.assertEquals(
      null,
      HealthConnectPortalLoginController.login(null, 'ValidPassword123!')
    );
    System.assertEquals(
      null,
      HealthConnectPortalLoginController.login('patient@example.test', '')
    );
    System.assertEquals(
      null,
      HealthConnectPortalLoginController.login('  ', 'ValidPassword123!')
    );
  }

  @IsTest
  static void returnsNoRedirectForInvalidCredentials() {
    Test.startTest();
    String redirectUrl = HealthConnectPortalLoginController.login(
      'missing.patient@example.test',
      'NotAValidPassword123!'
    );
    Test.stopTest();

    System.assertEquals(null, redirectUrl);
  }
}
