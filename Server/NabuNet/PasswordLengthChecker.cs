using System.Threading.Tasks;
using Microsoft.Extensions.Options;

namespace NabuNet
{
    public class PasswordLengthChecker
        : IPasswordQualityChecker
    {
        private readonly int _MinLength;

        public PasswordLengthChecker(IOptions<LoginSettings> settings)
        {
            _MinLength = settings.Value.MinimumPasswordLength;
        }

        public Task<string?> GetErrorForPasswordQuality(string propesedPassword)
        {
            if (propesedPassword.Length < _MinLength)
                return Task.FromResult<string?>(string.Format("The password needs to be at least {0} characters long!", _MinLength));
            return Task.FromResult<string?>(null);
        }
    }
}