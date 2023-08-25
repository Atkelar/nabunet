using System.ComponentModel.DataAnnotations;

namespace NabuNet.Models
{
    public class LoginModel2FA
    {
        [Required]
        [StringLength(32)]
        [RegularExpression("^[a-zA-Z][0-9a-zA-Z_.]{3,32}$")]
        [Display(Name = "User Name")]
        public string UserName { get; set; }
        [Required]
        public string LoginToken { get; set; }

        [Required]
        [RegularExpression("^\\d+$")]
        [MaxLength(16)] // just in case...
        [Display(Name = "Code")]
        public string ResponseCode { get; set; }
    }
}