using System.Threading.Tasks;

namespace NabuNet
{
    public interface ITemplateManager
    {
        Task<TemplateContent?> LoadTemplateAsync(string mailTemplateKey);
        Task UpdateTemplateAsync(string mailTemplateKey, string subject, string body);
    }
}