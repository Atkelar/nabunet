using System.ComponentModel.DataAnnotations;
using System.Threading.Tasks;

namespace NabuNet.Models
{
    public class Setup2FAModel
    {
        public string UserName { get; internal set; }
        public Setup2FAParameters? Parameters { get; internal set; }

        [RegularExpression(@"^\d+$")]
        [StringLength(10)]
        public string? Code { get; set; }
        public string Token { get; set; }
    }
}