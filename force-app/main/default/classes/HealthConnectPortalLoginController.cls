public with sharing class HealthConnectPortalLoginController {
  @AuraEnabled
  public static String login(String username, String password) {
    if (String.isBlank(username) || String.isBlank(password)) {
      return null;
    }

    PageReference destination = Site.login(username.trim(), password, null);
    return destination == null ? null : destination.getUrl();
  }
}
