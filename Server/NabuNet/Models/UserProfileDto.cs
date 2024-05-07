using System.ComponentModel;
using Org.BouncyCastle.Math.EC.Rfc7748;

namespace NabuNet.Models
{
    public class UserProfileDto
    {
        public UserProfileDto(string name)
        {
            IsComplete = false;
            Name = name;
        }

        public UserProfileDto(UserProfile userProfile)
        {
            IsComplete = true;
            Name = userProfile.Name;
            ContactEMail=userProfile.ContactEMail;
            DisplayName= userProfile.DisplayName;
            EnableAPIAccess=userProfile.EnableAPIAccess;
            EnableDeviceConnections=userProfile.EnableDeviceConnections;
            HighscoreName=userProfile.HighscoreName;
            IsAdministrator=userProfile.IsAdministrator;
            IsContentManager=userProfile.IsContentManager;
            IsEnabled=userProfile.IsEnabled;
            IsModerator=userProfile.IsModerator;
        }

        public bool IsComplete { get; set; }
        public string Name { get; set; }
        public string? ContactEMail { get; set; }
        public string DisplayName { get; set; }
        public bool EnableAPIAccess { get; }
        public bool EnableDeviceConnections { get; }
        public string HighscoreName { get; }
        public bool IsAdministrator { get; }
        public bool IsContentManager { get; }
        public bool IsEnabled { get; }
        public bool IsModerator { get; }
    }
}