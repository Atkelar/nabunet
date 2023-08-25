using System.ComponentModel.DataAnnotations;

namespace NabuNet.Models
{
    public class ForcePasswordChangeModel
    {
        public string UserName { get; set; }

        // If token is set, old password needs not be provided...
        public string? Token { get; set; }
        [Display(Name = "Old Password")]
        public string OldPassword { get; set; }
        [Required()]
        [Display(Name = "New Password")]
        public string NewPassword { get; set; }
        [Required()]
        [Compare(nameof(NewPassword))]
        [Display(Name = "Retype New Password")]
        public string NewPasswordRetype { get; set; }
    }
}