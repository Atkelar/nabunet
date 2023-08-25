using System.ComponentModel.DataAnnotations;

namespace NabuNet.Models
{
    public class LoginModel
    {
        [Required]
        [StringLength(32)]
        [RegularExpression("^[a-zA-Z][0-9a-zA-Z_.]{3,32}$")]
        [Display(Name = "User Name")]
        public string UserName { get; set; }
        [Required]
        [Display(Name = "Password")]
        public string Password { get; set; }
    }
}