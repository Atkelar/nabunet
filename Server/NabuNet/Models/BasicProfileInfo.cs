using System.ComponentModel.DataAnnotations;
using System.Threading.Tasks;

namespace NabuNet.Models
{
    // all user profile properties that a user may edit on their own account - reused for admin UI as well.
    public class BasicProfileInfo
    {
        public BasicProfileInfo()
        { }
        public BasicProfileInfo(UserProfile userProfile)
        {
            DisplayName = userProfile.DisplayName;
            HighScoreName = userProfile.HighscoreName;
            AllowAPIAccess = userProfile.EnableAPIAccess;
            AllowDeviceAccess = userProfile.EnableDeviceConnections;
            EMailAddress = userProfile.ContactEMail;
        }

        [Required]
        [StringLength(32)]  // might get used on the Nabu... special chars allowed, but will translate to "?" during ASCII encoding...
        [Display(Name = "Public Display Name")]
        public string DisplayName { get; set; }

        [StringLength(3)]
        [RegularExpression(@"^[a-zA-Z\./-0-9#+?%$!""@=[]{}&^;:<>']$")]  // limit to whatever we could type on the NABU keyboard...
        [Display(Name = "High Score Name")]
        public string? HighScoreName { get; set; }

        // set to false to disable all modem access tot his account. "Timeout" mode.
        [Display(Name = "Allow Device Access")]
        public bool AllowDeviceAccess { get; set; }

        // set to false to disable all token based logins for API access; i.e. disable all API login tokens.
        [Display(Name = "Allow API Access")]
        public bool AllowAPIAccess { get; set; }

        [MaxLength(128)]
        [EmailAddress]
        [Required]
        [Display(Name = "E-Mail Address")]
        public string EMailAddress { get; set; }
    }
}