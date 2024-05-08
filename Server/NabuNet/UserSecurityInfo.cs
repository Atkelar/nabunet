using System;

namespace NabuNet
{
    public class UserSecurityInfo
    {
        internal UserSecurityInfo(UserCredentials baseInfo)
        {
            Enable2FA = baseInfo.Enable2FA;
            Started2FASetup = baseInfo.Started2FASetup;
            Finished2FASetup = baseInfo.Finished2FASetup;

            ForcePasswordChange = baseInfo.ForcePasswordChange;

            LastValid2FAConfirm = baseInfo.LastValid2FAConfirm;
            LastValidPasswordLogin = baseInfo.LastValidPasswordLogin;

            MailValidationExpiration = baseInfo.MailValidationExpiration;
            ProposedMailAddress = baseInfo.ProposedMailAddress;
        }

        public bool Enable2FA { get; set; }
        public DateTime? Started2FASetup { get; set; }
        public bool Finished2FASetup { get; set; }
        public bool ForcePasswordChange { get; set; }
        public DateTime? LastValid2FAConfirm { get; set; }
        public DateTime? LastValidPasswordLogin { get; set; }
        public DateTime? MailValidationExpiration { get; set; }
        public string? ProposedMailAddress { get; set; }
    }
}