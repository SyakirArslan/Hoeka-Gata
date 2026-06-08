// HoekaGataIndicator license gate.
// Build per client by changing only these two constants.
// LICENSE_ACCOUNT = 0 allows any account.
// LICENSE_EXPIRES = 0 disables expiry.
// Expiry example: D'2026.12.31 23:59'
const long     LICENSE_ACCOUNT = 0;
const datetime LICENSE_EXPIRES = 0;

const int LICENSE_EXPIRY_WARNING_HOURS = 24;

string g_licenseLastReason = "";
bool   g_licenseExpiryWarningSent = false;

datetime LicenseNow()
{
   datetime now = TimeTradeServer();
   if(now <= 0)
      now = TimeCurrent();
   return now;
}

bool LicenseAllowed(string &reason)
{
   long account = (long)AccountInfoInteger(ACCOUNT_LOGIN);
   if(account <= 0)
   {
      reason = "waiting for account login";
      return false;
   }

   if(LICENSE_ACCOUNT > 0 && account != LICENSE_ACCOUNT)
   {
      reason = "invalid account " + IntegerToString(account);
      return false;
   }

   datetime now = LicenseNow();
   if(now <= 0)
   {
      reason = "waiting for server time";
      return false;
   }

   if(LICENSE_EXPIRES > 0 && now > LICENSE_EXPIRES)
   {
      reason = "expired " + TimeToString(LICENSE_EXPIRES, TIME_DATE | TIME_MINUTES);
      return false;
   }

   NotifyLicenseExpiryIfDue(now);

   reason = "OK";
   return true;
}

void NotifyLicenseExpiryIfDue(const datetime now)
{
   if(g_licenseExpiryWarningSent || LICENSE_EXPIRES <= 0 || now <= 0)
      return;

   int secondsRemaining = (int)(LICENSE_EXPIRES - now);
   if(secondsRemaining < 0 || secondsRemaining > LICENSE_EXPIRY_WARNING_HOURS * 3600)
      return;

   string message = "HoekaGataIndicator license expires in less than 1 day: " +
      TimeToString(LICENSE_EXPIRES, TIME_DATE | TIME_MINUTES);
   Print(message);
   Alert(message);
   if(InpEnablePushNotify)
      SendNotification(message);

   g_licenseExpiryWarningSent = true;
}

bool EnforceIndicatorLicense(const bool clearState)
{
   string reason = "";
   if(LicenseAllowed(reason))
   {
      if(g_licenseLastReason != "" && g_licenseLastReason != "OK")
         Print("HoekaGataIndicator license: valid");
      g_licenseLastReason = "OK";
      return true;
   }

   bool reasonChanged = reason != g_licenseLastReason;
   if(reasonChanged)
      Print("HoekaGataIndicator license: ", reason);
   g_licenseLastReason = reason;

   if(clearState)
      ClearPublishedSignalState();
   if(reasonChanged)
      DeleteObjectsByPrefix(PREFIX);

   return false;
}
