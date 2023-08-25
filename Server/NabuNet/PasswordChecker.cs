using System.Collections.Generic;
using System.Threading.Tasks;

namespace NabuNet
{
    public class PasswordChecker
    {
        private readonly IEnumerable<IPasswordQualityChecker> _Checkers;

        public PasswordChecker(IEnumerable<IPasswordQualityChecker> checkers)
        {
            _Checkers = checkers;
        }

        public async Task<IEnumerable<string>> ValidatePassword(string proposed)
        {
            List<string> result = new List<string>();

            foreach (var val in _Checkers)
            {
                var r = await val.GetErrorForPasswordQuality(proposed);
                if (r != null)
                    result.Add(r);
            }

            return result;
        }
    }
}