namespace NabuNet.Models
{
    public class PasswordResetInput
    {
        public string CurrentPassword { get; set; }
        public string NewPassword { get; set; }
        public string NewPasswordRetype { get; set; }
    }
}