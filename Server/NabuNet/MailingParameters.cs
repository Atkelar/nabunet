using System.Collections.Generic;

namespace NabuNet
{
    public class MailingParameters
    {
        public string MailTemplateKey { get; set; }

        public Dictionary<string, string> Values { get; set; }

        public IEnumerable<string> Recipients { get; set; }
        public IEnumerable<string> CCRecipients { get; set; }
        public IEnumerable<string> BCCRecipients { get; set; }
    }
}