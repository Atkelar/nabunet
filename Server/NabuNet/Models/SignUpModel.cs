using System.ComponentModel.DataAnnotations;

namespace NabuNet.Models
{
    public class SignUpModel
    {

        [Required]
        [StringLength(32)]
        [RegularExpression("^[a-zA-Z][0-9a-zA-Z_.]{3,32}$")]
        [Display(Name = "User Name")]
        public string UserName { get; set; }

        [Required]
        [Display(Name = "Password")]
        public string Password { get; set; }
        [Required]
        [Compare(nameof(Password))]
        [Display(Name = "Retype Password")]
        public string PasswordRetype { get; set; }

        [Required]
        [Display(Name = "Accept ToS")]
        public bool AcceptToS { get; set; }

        [Required]
        [EmailAddress]
        [Display(Name = "E-Mail Address")]
        public string EMail { get; set; }

        [Display(Name = "Enable 2FA")]
        public bool Enable2FA { get; set; }
        public bool Requries2FA { get; set; }
    }
}