using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using Microsoft.Extensions.Options;

namespace NabuNet
{
    internal class PwndPasswordsLookup
        : IPasswordQualityChecker
    {
        private readonly bool _Enabled;
        private readonly string _Url;
        private readonly IHttpClientFactory _Factory;

        public PwndPasswordsLookup(IOptions<LoginSettings> settings, System.Net.Http.IHttpClientFactory clientsFrom)
        {
            _Enabled = settings.Value.EnablePwndPasswords;
            _Url = settings.Value.PwndPasswordsApiUrl;
            _Factory = clientsFrom;
        }
        public async Task<string?> GetErrorForPasswordQuality(string propesedPassword)
        {
            if (!_Enabled)
                return null;    // we don't veto if we are disabled..
            var sha1 = System.Security.Cryptography.SHA1.Create();
            var hash = sha1.ComputeHash(Encoding.UTF8.GetBytes(propesedPassword));
            StringBuilder sb = new StringBuilder();
            foreach (var b in hash)
                sb.AppendFormat("{0:X2}", b);
            string fullHash = sb.ToString();
            string replyHash = fullHash.Substring(5);
            using (var cli = _Factory.CreateClient("pwndpasswords"))
            {
                using (var reasponse = await cli.GetStreamAsync(_Url.Replace("{}", fullHash.Substring(0, 5))))
                {
                    string? line;
                    using (var reader = new System.IO.StreamReader(reasponse))
                    {
                        while ((line = await reader.ReadLineAsync()) != null)
                        {
                            if (line.StartsWith(replyHash, true, null))
                            {
                                // we got a match!!
                                return string.Format("Sorry, the provided password has been found in {0} previous data breaches!",
                                    line.Substring(replyHash.Length).Trim(' ', ':'));
                            }
                        }
                    }
                }
            }
            return null;
        }
    }
}