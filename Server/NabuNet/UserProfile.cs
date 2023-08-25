using System;

namespace NabuNet
{
    public class UserProfile
        : IKeyRecord
    {
        public string? Id { get; set; }
        public string Name { get; set; }
        public string DisplayName { get; set; }
        public string HighscoreName { get; set; }
        // contact e-mail will only be non-null when it is validated (auto- or manual)
        public string? ContactEMail { get; set; }
        public bool EnableDeviceConnections { get; set; }
        public bool EnableAPIAccess { get; set; }
        public bool IsAdministrator { get; set; }
        public bool IsModerator { get; set; }
        public bool IsContentManager { get; set; }
        public bool IsUserAdministrator { get; set; }
        public bool IsEnabled { get; set; }

        public string DeriveNewKey()
        {
            return Name;
        }

        internal bool IsFullUser()
        {
            return IsEnabled && ContactEMail != null;
        }
    }
}