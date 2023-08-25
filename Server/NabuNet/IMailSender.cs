using System.Threading.Tasks;

namespace NabuNet
{
    public interface IMailSender
    {
        public Task<bool> TrySendMail(MailingParameters input);
    }
}