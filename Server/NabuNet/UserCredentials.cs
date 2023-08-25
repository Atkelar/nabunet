using System;

namespace NabuNet
{
    public class UserCredentials
        : IKeyRecord
    {
        public string? Id { get; set; }
        public bool ForcePasswordChange { get; set; }
        public DateTime? Started2FASetup { get; set; }
        public bool Finished2FASetup { get; set; }
        public bool Enable2FA { get; set; }
        public string? PWSalt { get; set; }
        public string? PWHash { get; set; }
        public string? TimeBasedSeed { get; set; }
        public Guid? MailValidationCode { get; set; }
        public DateTime? MailValidationExpiration { get; set; }
        public DateTime? LastValidPasswordLogin { get; set; }
        public long? LastUsed2FATime { get; set; }
        public DateTime? LastValid2FAConfirm { get; set; }
        public string? ProposedMailAddress { get; set; }

        public string DeriveNewKey()
        {
            throw new NotImplementedException("This should never be called! ID needs to be pre-set when attaching to profile!");
        }
    }
}