namespace NabuNet.Models
{
    public class ProfileSecurityInfo
    {
        public bool IsMFAEnabled { get; set; }
        public string? PasswordChangeError { get; set; }
        public bool PasswordChanged { get; set; }
    }
}