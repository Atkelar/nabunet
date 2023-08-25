namespace NabuNet
{

    public class LoginSettings
    {
        // Login timeout in seconds; the 2nd factor has to be presented within this timeout after the valid password has been entered.
        public int Login2FATimeout { get; set; } = 500;
        public bool EnablePwndPasswords { get; set; } = false;
        public string PwndPasswordsApiUrl { get; set; } = "https://api.pwnedpasswords.com/range/{}";
        public bool Require2FASignup { get; set; } = false;
        public bool Require2FAAdmin { get; set; } = true;
        public int MinimumPasswordLength { get; set; } = 10;
        // Timeout in MINUTES for the "validate your e-mail" message.
        public int MailValidationTimeout { get; set; } = 30;
        public int PageForwardingTimeout { get; set; } = 180;
        public int Digits2FACode { get; set; } = 6;
        public int Period2FACode { get; set; } = 30;
    }
}